// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../WitPriceFeeds.sol";
import "../data/WitPriceFeedsDataLib.sol";
import "../interfaces/IWitOracleQueriable.sol";
import "../interfaces/IWitPriceFeedsAdmin.sol";
import "../interfaces/IWitPriceFeedsConsumer.sol";
import "../mockups/WitPythChainlinkAggregator.sol";
import "../patterns/Clonable.sol";
import "../patterns/Ownable2Step.sol";

/// @title WitPriceFeedsV3: On-demand Price Feeds registry for EVM-compatible L1/L2 chains, 
/// natively powered by the Wit/Oracle blockchain, but yet capable of aggregating price 
/// updates from other on-chain price-feed oracles too, if required.
/// 
/// Price feeds purely relying on the Wit/Oracle present some advantanges, though:
/// - Anyone can permissionless pull and report price updates on-chain.
/// - Updating the price requires paying no extra "update fees".
/// - Prices can be extracted from independent and highly reputed exchanges and data providers.
/// - Actual data sources for each price feed can be introspected on-chain.
/// - Data source traceability in the Wit/Oracle blockchain is possible for every single price update.
///
/// Instances of this contract may also provide support for "routed price feeds" (computed as the 
/// product or mean average of up to other 8 different price feeds), as well as "cascade price feeds" 
/// (where multiple oracles could be used as backup when preferred ones don't manage to provide 
/// fresh enough updates for whatever reason).
///
/// Last but not least, this contract allows simple plug-and-play integration from 
/// smart contracts, dapps and DeFi projects currently adapted to operate with
/// other price feed solutions, like Chainlink, or Pyth. 
///
/// @author Guillermo Díaz <guillermo@witnet.io>

contract WitPriceFeedsV3
    is
        Clonable,
        Ownable2Step,
        WitPriceFeeds
{
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.RadonHash;
    using Witnet for Witnet.Timestamp;

    using WitPriceFeedsDataLib for ID4;
    using WitPriceFeedsDataLib for Mappers;
    using WitPriceFeedsDataLib for Oracles;
    using WitPriceFeedsDataLib for UpdateConditions;
    using WitPriceFeedsDataLib for WitPriceFeedsDataLib.PriceFeed;

    address immutable public override witOracle;

    function class() virtual override public pure returns (string memory) {
        return type(WitPriceFeedsV3).name;
    }

    constructor(
            address _witOracle,
            address _operator
        )
        Ownable(_operator != address(0) ? _operator : msg.sender)
    {
        require(
            _witOracle.code.length > 0,
            "inexistent wit/oracle"
        );
        bytes4 _witOracleSpecs = IWitAppliance(address(_witOracle)).specs();
        require(
            _witOracleSpecs == type(IWitOracle).interfaceId 
                || _witOracleSpecs == type(IWitOracle).interfaceId ^ type(IWitOracleQueriable).interfaceId,
            "uncompliant wit/oracle"
        );
        witOracle = _witOracle;
        __storage().defaultUpdateConditions = IWitPriceFeeds.UpdateConditions({
            callbackGas: 1_000_000,
            computeEma: false,
            cooldownSecs: 15 minutes,
            heartbeatSecs: 1 days,
            maxDeviation1000: 250, // 25.0 %
            minWitnesses: 3
        });
    }

    function initializeClone(bytes calldata initdata) 
        external
        initializer
        onlyDelegateCalls
        returns (address)
    {
        (address _operator, UpdateConditions memory _defaultConditions, Info[] memory _pfs) = abi.decode(
            initdata, 
            (address, UpdateConditions, Info[])
        );
        _transferOwnership(_operator);
        __storage().defaultUpdateConditions = _defaultConditions;
        for (uint _ix = 0; _ix < _pfs.length; _ix ++) {
            __settlePriceFeedOracle(
                _pfs[_ix].symbol,
                _pfs[_ix].exponent,
                _pfs[_ix].oracle.class,
                _pfs[_ix].oracle.target,
                _pfs[_ix].oracle.sources
            );
        }
        return address(this);
    }

    
    /// ===============================================================================================================
    /// --- Clonable --------------------------------------------------------------------------------------------------

    function initialized() virtual override public view returns (bool) {
        return(
            address(this) == _SELF
                || __storage().defaultUpdateConditions.minWitnesses > 0
        );
    }
    
    
    /// ===============================================================================================================
    /// --- IERC2362 --------------------------------------------------------------------------------------------------

    function valueFor(bytes32 _id)
        override
        external view
        returns (int256 _value, uint256 _timestamp, uint256 _status)
    {
        ID4 _id4 = ID4.wrap(bytes4(_id));
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(_id4);
        UpdateConditions memory _updateConditions = __record.updateConditions.coalesce();
        WitPriceFeedsDataLib.PriceData memory _lastUpdate = __record.fetchLastUpdate(_id4, _updateConditions.heartbeatSecs);
        _value = int(uint(_lastUpdate.emaPrice > 0 ? _lastUpdate.emaPrice : _lastUpdate.price));
        _timestamp = uint(Witnet.Timestamp.unwrap(_lastUpdate.timestamp));
        _status = (
            _timestamp == 0 
                ? 404
                : (
                    block.timestamp > Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + _updateConditions.heartbeatSecs
                        ? 400 
                        : 200
                )
        );
    }

    
    /// ===============================================================================================================
    /// --- IWitPyth --------------------------------------------------------------------------------------------------

    /// @notice Returns the exponentially-weighted moving average price.
    /// @dev Reverts if the EMA price is not available, or if the price feeds is settled with a heartbeat
    /// and the price was not recently updated.
    /// @param _id The Price Feed ID of which to fetch the EMA price.
    function getEmaPrice(ID _id)
        external view override 
        returns (PythPrice memory)
    {
        return _intoPythPrice(
            WitPriceFeedsDataLib.getPrice(_intoID4(_id))
        );
    }

    /// @notice Returns the exponentially-weighted moving average price that is no older than `_age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    function getEmaPriceNotOlderThan(ID _id, uint64 _age)
        external view override
        returns (PythPrice memory)
    {
        return _intoPythPrice(
            WitPriceFeedsDataLib.getPriceNotOlderThan(_intoID4(_id), uint24(_age))
        );
    }

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    function getEmaPriceUnsafe(ID _id)
        external view override 
        returns (PythPrice memory) 
    {
        return _intoPythPrice(
            WitPriceFeedsDataLib.getPriceUnsafe(_intoID4(_id))
        );
    }

    /// @notice Returns the price of given price feed.
    /// @dev Reverts if the price has not been updated within the last `heartbeatSecs`. 
    /// @param _id The Price Feed ID of which to fetch the price.
    function getPrice(ID _id)
        external view override
        returns (PythPrice memory)
    {
        return _intoPythPrice(
            WitPriceFeedsDataLib.getPrice(_intoID4(_id))
        );
    }

    /// @notice Returns the price that is no older than `_age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. 
    /// Reverts if the price wasn't updated sufficiently
    /// recently.
    function getPriceNotOlderThan(ID _id, uint64 _age)
        external view override 
        returns (PythPrice memory)
    {
        return _intoPythPrice(
            WitPriceFeedsDataLib.getPriceNotOlderThan(_intoID4(_id), uint24(_age))
        );
    }

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    /// 
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    function getPriceUnsafe(ID _id)
        external view override
        returns (PythPrice memory)
    {
        return _intoPythPrice(
            WitPriceFeedsDataLib.getPriceUnsafe(_intoID4(_id))
        );
    }

    /// @notice Legacy-compliant to get the required fee to update an array of price updates, which would be
    /// always 0 if relying from the Wit/Oracle framework.
    function getUpdateFee(bytes calldata) external override pure returns (uint256) {
        return 0;
    }


    /// ===============================================================================================================
    /// --- IWitPriceFeeds --------------------------------------------------------------------------------------------

    /// Creates a light-proxy clone to the underlying logic contract, owned by the specified `operator` address. 
    /// Operators of cloned contracts can optionally settle one single price feed `IWitPriceFeedConsumer` contract. 
    /// The consumer contract, if settled, will be immediately reported upon every verified price update pushed 
    /// into `WitPriceFeeds`. Either way, price feeds data will be stored in the `WitPriceFeeds` storage. 
    /// @dev Reverts if the salt has already been used, or trying to inherit mapped price feeds.
    /// @param _salt Salt that will determine the address of the new light-proxy clone.
    /// @param _operator Address that will have rights to manage price feeds on the new light-proxy clone.
    /// @param _id4s Array of price feeds to inherit from the instance being cloned.
    function clone(
            bytes32 _salt,
            address _operator, 
            ID4[] calldata _id4s
        ) 
        virtual override
        external
        returns (address)
    {
        Info[] memory _pfs = new Info[](_id4s.length);
        for (uint _ix = 0; _ix < _pfs.length; _ix ++) {
            _pfs[_ix] = lookupPriceFeed(_id4s[_ix]);
            require(_pfs[_ix].mapper.class == Mappers.None, "mapped price feed");
        }
        return WitPriceFeedsV3(_cloneDeterministic(_salt))
            .initializeClone(abi.encode(
                _operator,
                __storage().defaultUpdateConditions,
                _pfs
            ));
    }

    ///Address of contract from which this one was cloned.
    function master() 
        virtual override
        public view 
        returns (address)
    {
        return cloned() ? self() : address(0);
    }

    /// Returns the soul-bounded address where all price updates will be reported to.
    /// @dev If zero, price updates will not be reported to any other external address.
    /// @dev It can only be settled or changed by cloning the contract.
    /// @dev Price feeds metadata and update information will be stored in this contract,
    /// @dev even if there's a soulbound address settled.
    function consumer() override external view returns (address) {
        return __storage().consumer;
    }

    /// Creates a Chainlink Aggregator proxy to the specified symbol.
    /// @dev Reverts if symbol is not supported.
    function createChainlinkAggregator(string calldata symbol)
        virtual override external
        returns (IWitPythChainlinkAggregator)
    {
        require(supportsCaption(symbol), PriceFeedNotFound());
        bytes memory _initcode = type(WitPythChainlinkAggregator).creationCode;
        bytes memory _params = abi.encodePacked(address(this), _intoID4(hash(symbol)));
        address _aggregator = _determineCreate2Address(_initcode, _params);
        if (_aggregator.code.length == 0) {
            bytes memory _bytecode = _completeInitCode(_initcode, _params);
            assembly {
                _aggregator := create2(
                    0,
                    add(_bytecode, 0x20),
                    mload(_bytecode),
                    0
                )
            }
        }
        return IWitPythChainlinkAggregator(_aggregator);
    }

    /// @notice Returns last update price for the specified ID4 price feed.
    /// Note: This function is sanity-checked version of `getPriceUnsafe` which is useful in applications and
    /// smart contracts that require recentl updated price, and no hint of market deviation being currently excessive. 
    ///
    /// @dev Reverts if:
    /// - `StalePrice()`: the price feed has not been updated within the last `UpdateConditions.heartbeatSecs`,
    /// - `DeviantPrice()`: a deviation greater than `UpdateConditions.maxDeviation1000` was detected upon last update attempt.
    /// - `InvalidGovernanceTarget()`: no EMA is curretly settled to be computed for this price feed.
    ///
    /// @param _id4 Unique ID4 identifier of a price feed supported by this contract.
    function getPrice(ID4 _id4) external view override returns (Price memory) {
        return WitPriceFeedsDataLib.getPrice(_id4);
    }

    /// @notice Returns last known price if no older than `_age` seconds of the current time.
    /// Note: This function is a sanity-checked version of `getPriceUnsafe` which is useful in applications and
    /// smart contracts that require last known non-deviant price, last updated within specified time range.
    ///
    /// @dev Reverts if:
    /// - `StalePrice()`: the price feed has not been updated within the last `_age` seconds,
    /// 
    /// @param _id4 Unique ID4 identifier of a price feed supported by this contract.
    /// @param _age Maximum age of acceptable price value.
    function getPriceNotOlderThan(ID4 _id4, uint24 _age) external view override returns (Price memory) {
        return WitPriceFeedsDataLib.getPriceNotOlderThan(_id4, _age);
    }

    /// @notice Returns last updated price without any sanity checks.
    /// Note: This function is unsafe as the returned price update may be arbitrarily far in the past.
    /// Users of this function should check the `timestamp` of each price feed to ensure that the returned values 
    /// are sufficiently recent for their application. If you need safe access to fresh data, please consider
    /// using calling to either `getPrice` or `getPriceNoOlderThan` variants.
    /// 
    /// @param _id4 Unique ID4 identifier of a price feed supported by this contract.
    function getPriceUnsafe(ID4 _id4) external view override returns (Price memory) {
        return WitPriceFeedsDataLib.getPriceUnsafe(_id4);
    }

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint() external override view returns (bytes4 _footprint) {
        return __storage().footprint;
    }
    
    /// Determines unique ID for specified `symbol` string.
    function hash(string memory _symbol) public pure returns (ID) {
        return ID.wrap(WitPriceFeedsDataLib.hash(_symbol));
    }
    
    function lookupPriceFeed(ID4 _id4)
        override 
        public view 
        returns (Info memory)
    {
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(_id4);
        Mappers _mapper = __record.mapper;
        string[] memory _mapperDeps;
        if (_mapper != Mappers.None) {
            ID4[] memory _deps = _id4.deps();
            _mapperDeps = new string[](_deps.length);
            for (uint _ix = 0; _ix < _deps.length; ++ _ix) {
                _mapperDeps[_ix] = __storage().records[_deps[_ix]].symbol;
            }
        }
        Oracles _oracle = __record.oracle;
        bytes32 _oracleSources = __record.oracleSources;
        address _oracleAddress = __record.oracleAddress;

        return Info({
            id: _intoID(_id4),
            exponent: __record.exponent,
            symbol: __record.symbol,
            mapper: Mapper({
                class: _mapper,
                deps: _mapperDeps
            }),
            oracle: Oracle({
                class: _oracle,
                target: _oracleAddress,
                sources: _oracleSources
            }),
            updateConditions: __record.updateConditions.coalesce(),
            lastUpdate: WitPriceFeedsDataLib.getPriceUnsafe(_id4)
        });
    }

    function lookupPriceFeedCaption(ID4 _id4) external override view returns (string memory _symbol) {
        return __seekPriceFeed(_id4).symbol;
    }

    function lookupPriceFeedExponent(ID4 _id4) override public view returns (int8) {
        return __seekPriceFeed(_id4).exponent;
    }

    function lookupPriceFeedID(ID4 _id4) override public view returns (bytes32) {
        return IWitPyth.ID.unwrap(_intoID(_id4));
    }
    
    function lookupPriceFeeds() external override view returns (Info[] memory _infos) {
        ID[] storage __ids = __storage().ids;
        _infos = new Info[](__ids.length);
        for (uint _ix; _ix < _infos.length; ++ _ix) {
            _infos[_ix] = lookupPriceFeed(_intoID4(__ids[_ix]));
        }
    }

    function supportsCaption(string calldata _caption) public override view returns (bool) {
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(_intoID4(hash(_caption)));
        return __record.settled();
    }


    /// ===============================================================================================================
    /// --- IWitPriceFeedsAdmin ---------------------------------------------------------------------------------------

    function acceptOwnership()
        virtual override (IWitPriceFeedsAdmin, Ownable2Step)
        public
    {
        Ownable2Step.acceptOwnership();
    }

    function defaultUpdateConditions()
        external view override
        returns (IWitPriceFeeds.UpdateConditions memory)
    {
        return __storage().defaultUpdateConditions;
    }

    function owner()
        virtual override (IWitPriceFeedsAdmin, Ownable)
        public view 
        returns (address)
    {
        return Ownable.owner();
    }

    function pendingOwner() 
        virtual override (IWitPriceFeedsAdmin, Ownable2Step)
        public view
        returns (address)
    {
        return Ownable2Step.pendingOwner();
    }
    
    function transferOwnership(address _newOwner)
        virtual override (IWitPriceFeedsAdmin, Ownable2Step)
        public 
        onlyOwner
    {
        Ownable.transferOwnership(_newOwner);
    }

    function removePriceFeed(string calldata _symbol, bool _recursively) 
        external override
        onlyOwner
        returns (bytes4 _footprint)
    {
        IWitPriceFeeds.ID4 _id4 = _intoID4(hash(_symbol));
        WitPriceFeedsDataLib.removePriceFeed(_id4, _recursively);
        emit IWitPriceFeedsAdmin.PriceFeedRemoved(
            msg.sender, 
            _id4, 
            _symbol
        );
        return WitPriceFeedsDataLib.settlePriceFeedFootprint();
    }

    function settleConsumer(address _consumer)
        external override
        onlyDelegateCalls
        onlyOwner
    {
        _require(
            _consumer != address(this)
                && _consumer != _SELF
                && _consumer.code.length > 0 // must be a contract
                && IWitPriceFeedsConsumer(_consumer).witPriceFeeds() == address(this) 
                && IWitPriceFeedsConsumer(_consumer).witOracle() == witOracle,
            "invalid consumer"
        );
        __storage().consumer = _consumer;
    }

    function settleDefaultUpdateConditions(IWitPriceFeeds.UpdateConditions calldata _conditions)
        external override
        onlyOwner
    {
        __storage().defaultUpdateConditions = _conditions;
    }

    function settlePriceFeedMapper(
            string calldata _symbol, 
            int8 _exponent,
            Mappers _mapper,
            string[] calldata _deps
        ) 
        external override
        onlyOwner
        returns (bytes4)
    {
        try WitPriceFeedsDataLib
            .settlePriceFeedMapper(
                _symbol, 
                _exponent, 
                _mapper,
                _deps
            )
        returns (bytes4 _footprint) { 
            emit PriceFeedMapper(
                msg.sender,
                _intoID4(hash(_symbol)),
                _symbol,
                _exponent,
                _mapper,
                _deps
            );
            return _footprint; 
        
        } catch Error(string memory _reason) { 
            _revert(_reason); 
        
        } catch (bytes memory) {
            _revertUnhandled(); 
        }
    }

    function settlePriceFeedOracle(
            string calldata _symbol, 
            int8 _exponent,
            Oracles _oracle,
            address _oracleAddress,
            bytes32 _oracleSources
        ) 
        external override
        onlyOwner
        returns (bytes4)
    {
        return __settlePriceFeedOracle(_symbol, _exponent, _oracle, _oracleAddress, _oracleSources);
    }

    function settlePriceFeedRadonBytecode(
            string calldata _symbol, 
            int8 _exponent,
            bytes calldata _radonBytecode
        )
        external override 
        onlyOwner
        returns (bytes4)
    {
        try WitPriceFeedsDataLib
            .settlePriceFeedRadonBytecode(
                _symbol,
                _radonBytecode,
                _exponent,
                IWitOracle(witOracle).registry()
            )
        returns (bytes4 _footprint, Witnet.RadonHash _radonHash) {
            emit PriceFeedOracle(
                msg.sender,
                _intoID4(hash(_symbol)),
                _symbol,
                _exponent,
                IWitPriceFeeds.Oracles.Witnet,
                address(this),
                Witnet.RadonHash.unwrap(_radonHash)
            );
            return _footprint;
        
        } catch Error(string memory _reason) { 
            _revert(_reason); 
        
        } catch (bytes memory) {
            _revertUnhandled(); 
        }
    }

    function settlePriceFeedRadonHash(
            string calldata _symbol, 
            int8 _exponent,
            Witnet.RadonHash _radonHash
        )
        external override 
        onlyOwner
        returns (bytes4)
    {
        try WitPriceFeedsDataLib
            .settlePriceFeedRadonHash(
                _symbol,
                _radonHash,
                _exponent,
                IWitOracle(witOracle).registry()
            )
        returns (bytes4 _footprint) {
            emit PriceFeedOracle(
                msg.sender,
                _intoID4(hash(_symbol)),
                _symbol,
                _exponent,
                Oracles.Witnet,
                address(this),
                Witnet.RadonHash.unwrap(_radonHash)
            );
            return _footprint;
        }
        catch Error(string memory _reason) { 
            _revert(_reason); 
        
        } catch (bytes memory) {
            _revertUnhandled(); 
        }
    }

    function settlePriceFeedUpdateConditions(
            string calldata _symbol, 
            IWitPriceFeeds.UpdateConditions calldata _conditions
        )
        external override
        onlyOwner
    {
        __settlePriceFeedUpdateConditions(_symbol, _conditions);
    }


    /// ===============================================================================================================
    /// --- IWitOracleConsumer ----------------------------------------------------------------------------------------

    function pushDataReport(
            Witnet.DataPushReport calldata report, 
            bytes calldata proof
        )
        virtual override
        public
    {
        ID4 _id4 = __storage().reverseIds[report.queryRadHash];
        require(
            !_id4.isZero(), 
            InvalidUpdateDataSource()
        );
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(_id4);
        UpdateConditions memory _updateConditions = __record.updateConditions.coalesce();
        require(
            report.queryParams.witCommitteeSize >= _updateConditions.minWitnesses,
            InvalidGovernanceTarget()
        );
        Witnet.DataResult memory _dataResult = IWitOracle(witOracle).pushDataReport(
            report,
            proof
        );
        require(
            _dataResult.status == Witnet.ResultStatus.NoErrors
                && _dataResult.dataType == Witnet.RadonDataTypes.Integer,
            InvalidUpdateData()
        );
        require(
            _dataResult.timestamp.gt(__record.lastUpdate.timestamp),
            NoFreshUpdate()
        );
        require(
            Witnet.Timestamp.unwrap(_dataResult.timestamp)
                >= Witnet.Timestamp.unwrap(__record.lastUpdate.timestamp) + _updateConditions.cooldownSecs,
            HotPrice()
        );
        
        int8 _exponent = __record.lastUpdate.exponent;
        uint64 _deltaSecs = uint24(
            Witnet.Timestamp.unwrap(__record.lastUpdate.timestamp)
                - Witnet.Timestamp.unwrap(_dataResult.timestamp)
        );
        uint64 _lastPrice = __record.lastUpdate.price;
        uint64 _nextPrice = _dataResult.fetchUint();
        int56 _deltaPrice = int56(int64(_nextPrice) - int64(_lastPrice));
        uint64 _deviation1000 = (
            _deltaPrice >= 0
                ? uint56(_deltaPrice * 1000) / _lastPrice
                : uint56(-_deltaPrice * 1000) / _lastPrice
        );
        
        require(
            _deviation1000 <= _updateConditions.maxDeviation1000,
            DeviantPrice()
        );

        __record.lastUpdate.deltaPrice = _deltaPrice;
        __record.lastUpdate.price = _nextPrice;
        __record.lastUpdate.timestamp = _dataResult.timestamp;
        __record.lastUpdate.trail = _dataResult.drTxHash;

        if (_updateConditions.computeEma) {
            // TODO
            // ...
            /// __record.lastUpdate.emaPrice = x;
        }
        
        if (__storage().consumer == address(0)) {
            emit IWitPriceFeeds.PriceFeedUpdate(
                _id4,
                _dataResult.timestamp,
                _dataResult.drTxHash,
                _nextPrice,
                _deltaPrice,
                _exponent
            );
        } else {
            IWitPriceFeedsConsumer(__storage().consumer).reportUpdate(
                _id4,
                _dataResult.timestamp,
                _dataResult.drTxHash,
                _nextPrice,
                _deltaPrice,
                _deltaSecs,
                _exponent
            );
        }
    }

    
    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _completeInitCode(bytes memory initcode, bytes memory params)
        private pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            initcode,
            params
        );
    }

    function _determineCreate2Address(bytes memory initcode, bytes memory params)
        private view
        returns (address)
    {
        return address(
            uint160(uint(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    bytes32(0),
                    keccak256(_completeInitCode(initcode, params))
                )
            )))
        );
    }

    function _intoID(ID4 id4) internal view returns (ID) {
        return __storage().ids[__storage().records[id4].index];
    }

    function _intoID4(ID id) internal pure returns (ID4) {
        return ID4.wrap(bytes4(ID.unwrap(id)));
    }

    function _intoPythPrice(Price memory _witPrice) internal pure returns (PythPrice memory) {
        return PythPrice({
            price: int64(_witPrice.price),
            conf: 0,
            expo: int32(_witPrice.exponent),
            publishTime: uint(Witnet.Timestamp.unwrap(_witPrice.timestamp))
        });
    }

    function _revertUnhandled() internal view {
        _revert("unhandled revert");
    }

    function __seekPriceFeed(ID4 _id4) internal view returns (WitPriceFeedsDataLib.PriceFeed storage) {
        return WitPriceFeedsDataLib.seekPriceFeed(_id4);
    }

    function __settlePriceFeedOracle(
            string memory _symbol, 
            int8 _exponent,
            Oracles _oracle,
            address _oracleAddress,
            bytes32 _oracleSources
        )
        virtual internal 
        returns (bytes4)
    {
        try WitPriceFeedsDataLib
            .settlePriceFeedOracle(
                _symbol, 
                _exponent, 
                _oracle,
                _oracleAddress,
                _oracleSources
            )
        returns (bytes4 _footprint) { 
            emit PriceFeedOracle(
                msg.sender,
                _intoID4(hash(_symbol)),
                _symbol,
                _exponent,
                _oracle,
                _oracleAddress,
                _oracleSources
            );
            return _footprint; 
        
        } catch Error(string memory _reason) { 
            _revert(_reason); 
        
        } catch (bytes memory) {
            _revertUnhandled(); 
        }
    }

    function __settlePriceFeedUpdateConditions(
            string memory _symbol,
            IWitPriceFeeds.UpdateConditions memory _conditions
        )
        virtual internal 
    {
        ID4 _id4 = _intoID4(hash(_symbol));
        WitPriceFeedsDataLib.PriceFeed storage __pf = __seekPriceFeed(_id4);
        __pf.updateConditions = _conditions;
        if (!_conditions.computeEma) {
            __pf.lastUpdate.emaPrice = 0;
        }
        emit PriceFeedSettled(
            _msgSender(),
            _id4,
            _symbol,
            _conditions
        );
    }

    function __storage() internal pure returns (WitPriceFeedsDataLib.Storage storage) {
        return WitPriceFeedsDataLib.data();
    }

}
