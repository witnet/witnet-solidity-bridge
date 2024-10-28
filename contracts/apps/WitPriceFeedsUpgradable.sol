// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../WitPriceFeeds.sol";
import "../core/WitnetUpgradableBase.sol";
import "../data/WitPriceFeedsData.sol";
import "../interfaces/IWitFeedsAdmin.sol";
import "../interfaces/IWitFeedsLegacy.sol";
import "../interfaces/IWitPriceFeedsSolverFactory.sol";
import "../interfaces/IWitOracleLegacy.sol";
import "../libs/WitPriceFeedsLib.sol";
import "../patterns/Ownable2Step.sol";

/// @title WitPriceFeeds: Price Feeds live repository reliant on the Witnet Oracle blockchain.
/// @author Guillermo Díaz <guillermo@otherplane.com>

contract WitPriceFeedsUpgradable
    is
        Ownable2Step,
        WitPriceFeeds,
        WitPriceFeedsData,
        WitnetUpgradableBase,
        IWitFeedsAdmin,
        IWitFeedsLegacy,
        IWitPriceFeedsSolverFactory
{
    using Witnet for bytes;
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.QueryResponse;
    using Witnet for Witnet.QuerySLA;
    using Witnet for Witnet.ResultStatus;


    function class() virtual override public view returns (string memory) {
        return type(WitPriceFeedsUpgradable).name;
    }

    WitOracle immutable public override witOracle;
    WitOracleRadonRegistry immutable internal __registry;

    Witnet.QuerySLA private __defaultRadonSLA;
    uint16 private __baseFeeOverheadPercentage;
    
    constructor(
            WitOracle _witOracle,
            bytes32 _versionTag,
            bool _upgradable
        )
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.feeds.price"
        )
    {
        _require(
            address(_witOracle).code.length > 0,
            "inexistent oracle"
        );
        _require(
            _witOracle.specs() == (
                type(IWitAppliance).interfaceId
                    ^ type(IWitOracle).interfaceId
            ), "uncompliant oracle"
        );
        witOracle = _witOracle;
    }

    function _registry() virtual internal view returns (WitOracleRadonRegistry) {
        return witOracle.registry();
    }

    // solhint-disable-next-line payable-fallback
    fallback() override external {
        if (
            msg.sig == IWitPriceFeedsSolver.solve.selector
                && msg.sender == address(this)
        ) {
            address _solver = __records_(bytes4(bytes8(msg.data) << 32)).solver;
            _require(
                _solver != address(0),
                "unsettled solver"
            );
            assembly {
                let ptr := mload(0x40)
                calldatacopy(ptr, 0, calldatasize())
                let result := delegatecall(gas(), _solver, ptr, calldatasize(), 0, 0)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                switch result
                    case 0 { revert(ptr, size) }
                    default { return(ptr, size) }
            }
        } else {
            _revert("not implemented");
        }
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory _initData) virtual override internal {
        if (__proxiable().codehash == bytes32(0)) {
            __defaultRadonSLA = Witnet.QuerySLA({
                witCommitteeCapacity: 10,
                witCommitteeUnitaryReward: 2 * 10 ** 8,
                witResultMaxSize: 16,
                witCapability: Witnet.QueryCapability.wrap(0)
            });
            // settle default base fee overhead percentage
            __baseFeeOverheadPercentage = 10;
        } else {
            // otherwise, store beacon read from _initData, if any
            if (_initData.length > 0) {
                (uint16 _baseFeeOverheadPercentage, Witnet.QuerySLA memory _defaultRadonSLA) = abi.decode(
                    _initData, (uint16, Witnet.QuerySLA)
                );
                __baseFeeOverheadPercentage = _baseFeeOverheadPercentage;
                __defaultRadonSLA = _defaultRadonSLA;
            } else if (__defaultRadonSLA.witResultMaxSize < 16) {
                // possibly, an upgrade from a previous branch took place:
                __defaultRadonSLA.witResultMaxSize = 16;
            }
        }
    }


    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = owner();
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }


    // ================================================================================================================
    // --- Implements 'IFeeds' ----------------------------------------------------------------------------------------

    /// @notice Returns unique hash determined by the combination of data sources being used
    /// @notice on non-routed price feeds, and dependencies of routed price feeds.
    /// @dev Ergo, `footprint()` changes if any data source is modified, or the dependecy tree
    /// @dev on any routed price feed is altered.
    function footprint() 
        virtual override
        public view
        returns (bytes4 _footprint)
    {
        if (__storage().ids.length > 0) {
            _footprint = _footprintOf(__storage().ids[0]);
            for (uint _ix = 1; _ix < __storage().ids.length; _ix ++) {
                _footprint ^= _footprintOf(__storage().ids[_ix]);
            }
        }
    }

    function hash(string memory caption)
        virtual override
        public pure
        returns (bytes4)
    {
        return bytes4(keccak256(bytes(caption)));
    }

    function lookupCaption(bytes4 feedId)
        override
        public view
        returns (string memory)
    {
        return __records_(feedId).caption;
    }

    function supportedFeeds()
        virtual override
        external view
        returns (bytes4[] memory _ids, string[] memory _captions, bytes32[] memory _solvers)
    {
        _ids = __storage().ids;
        _captions = new string[](_ids.length);
        _solvers = new bytes32[](_ids.length);
        for (uint _ix = 0; _ix < _ids.length; _ix ++) {
            Record storage __record = __records_(_ids[_ix]);
            _captions[_ix] = __record.caption;
            _solvers[_ix] = address(__record.solver) == address(0) ? __record.radHash : bytes32(bytes20(__record.solver));
        }
    }
    
    function supportsCaption(string calldata caption)
        virtual override
        external view
        returns (bool)
    {
        bytes4 feedId = hash(caption);
        return hash(__records_(feedId).caption) == feedId;
    }
    
    function totalFeeds() 
        override 
        external view
        returns (uint256)
    {
        return __storage().ids.length;
    }


    // ================================================================================================================
    // --- Implements 'IWitFeeds' ----------------------------------------------------------------------------------

    function defaultRadonSLA()
        override
        public view
        returns (Witnet.QuerySLA memory)
    {
        return __defaultRadonSLA;
    }

    function estimateUpdateBaseFee(uint256 _evmGasPrice) virtual override public view returns (uint256) {
        return estimateUpdateRequestFee(_evmGasPrice);
    }
    
    function estimateUpdateRequestFee(uint256 _evmGasPrice)
        virtual override
        public view
        returns (uint)
    {
        return (IWitOracleLegacy(address(witOracle)).estimateBaseFee(_evmGasPrice, 32)
            * (100 + __baseFeeOverheadPercentage)
        ) / 100; 
    }

    function lastValidQueryId(bytes4 feedId)
        override public view
        returns (Witnet.QueryId)
    {
        return _lastValidQueryId(feedId);
    }

    function lastValidQueryResponse(bytes4 feedId)
        override public view
        returns (Witnet.QueryResponse memory)
    {
        return witOracle.getQueryResponse(_lastValidQueryId(feedId));
    }

    function latestUpdateQueryId(bytes4 feedId)
        override public view
        returns (Witnet.QueryId)
    {
        return __records_(feedId).latestUpdateQueryId;
    }

    function latestUpdateQueryRequest(bytes4 feedId)
        override external view 
        returns (Witnet.QueryRequest memory)
    {
        return witOracle.getQueryRequest(latestUpdateQueryId(feedId));
    }

    function latestUpdateQueryResult(bytes4 feedId)
        override external view
        returns (Witnet.DataResult memory)
    {
        return witOracle.getQueryResult(latestUpdateQueryId(feedId));
    }

    function latestUpdateQueryResultStatus(bytes4 feedId)
        override public view
        returns (Witnet.ResultStatus)
    {
        return _coalesceQueryResultStatus(latestUpdateQueryId(feedId));
    }

    function latestUpdateQueryResultStatusDescription(bytes4 feedId) 
        override external view
        returns (string memory)
    {
        return witOracle.getQueryResultStatusDescription(
            latestUpdateQueryId(feedId)
        );
    }

    function lookupWitOracleRequestBytecode(bytes4 feedId)
        override public view
        returns (bytes memory)
    {
        Record storage __record = __records_(feedId);
        _require(
            __record.radHash != 0,
            "no RAD hash"
        );
        return _registry().bytecodeOf(__record.radHash);
    }

    function lookupWitOracleRequestRadHash(bytes4 feedId)
        override public view
        returns (bytes32)
    {
        return __records_(feedId).radHash;
    }

    function lookupWitOracleRadonRetrievals(bytes4 feedId)
        override external view
        returns (Witnet.RadonRetrieval[] memory _retrievals)
    {
        return _registry().lookupRadonRequestRetrievals(
            lookupWitOracleRequestRadHash(feedId)
        );
    }

    function requestUpdate(bytes4 feedId)
        external payable
        virtual override
        returns (uint256)
    {
        return __requestUpdate(feedId, __defaultRadonSLA);
    }
    
    function requestUpdate(bytes4 feedId, Witnet.QuerySLA calldata updateSLA)
        public payable
        virtual override
        returns (uint256 _usedFunds)
    {
        _require(
            updateSLA.equalOrGreaterThan(__defaultRadonSLA),
            "unsecure update"
        );
        return __requestUpdate(feedId, updateSLA);
    }
    

    /// ===============================================================================================================
    /// --- IWitFeedsLegacy -------------------------------------------------------------------------------------------
    
    function latestUpdateResponse(bytes4 feedId) 
        override external view 
        returns (Witnet.QueryResponse memory)
    {
        return witOracle.getQueryResponse(latestUpdateQueryId(feedId));
    }

    function latestUpdateResponseStatus(bytes4 feedId)
        override public view
        returns (IWitOracleLegacy.QueryResponseStatus)
    {
        return IWitOracleLegacy(address(witOracle)).getQueryResponseStatus(
            Witnet.QueryId.unwrap(latestUpdateQueryId(feedId))
        );
    }

    function latestUpdateResultError(bytes4 feedId)
        override external view 
        returns (IWitOracleLegacy.ResultError memory)
    {
        return IWitOracleLegacy(address(witOracle)).getQueryResultError(Witnet.QueryId.unwrap(latestUpdateQueryId(feedId)));
    }

    function lookupWitnetBytecode(bytes4 feedId) 
        override external view
        returns (bytes memory)
    {
        return lookupWitOracleRequestBytecode(feedId);
    }
    
    function requestUpdate(bytes4 feedId, IWitFeedsLegacy.RadonSLA calldata updateSLA)
        external payable
        virtual override
        returns (uint256)
    {
        return __requestUpdate(
            feedId, 
            Witnet.QuerySLA({
                witCommitteeCapacity: updateSLA.witCommitteeCapacity,
                witCommitteeUnitaryReward: updateSLA.witCommitteeUnitaryReward,
                witResultMaxSize: __defaultRadonSLA.witResultMaxSize,
                witCapability: Witnet.QueryCapability.wrap(0)
            })
        );
    }

    function witnet() virtual override external view returns (address) {
        return address(witOracle);
    }


    // ================================================================================================================
    // --- Implements 'IWitFeedsAdmin' -----------------------------------------------------------------------------

    function owner()
        virtual override (IWitFeedsAdmin, Ownable)
        public view 
        returns (address)
    {
        return Ownable.owner();
    }
    
    function acceptOwnership()
        virtual override (IWitFeedsAdmin, Ownable2Step)
        public
    {
        Ownable2Step.acceptOwnership();
    }

    function baseFeeOverheadPercentage()
        virtual override
        external view
        returns (uint16)
    {
        return __baseFeeOverheadPercentage;
    }

    function pendingOwner() 
        virtual override (IWitFeedsAdmin, Ownable2Step)
        public view
        returns (address)
    {
        return Ownable2Step.pendingOwner();
    }
    
    function transferOwnership(address _newOwner)
        virtual override (IWitFeedsAdmin, Ownable2Step)
        public 
        onlyOwner
    {
        Ownable.transferOwnership(_newOwner);
    }

    function deleteFeed(string calldata caption)
        virtual override
        external 
        onlyOwner
    {
        bytes4 feedId = hash(caption);
        bytes4[] storage __ids = __storage().ids;
        Record storage __record = __records_(feedId);
        uint _index = __record.index;
        _require(_index != 0, "unknown feed");
        {
            bytes4 _lastFeedId = __ids[__ids.length - 1];
            __ids[_index - 1] = _lastFeedId;
            __ids.pop();
            __records_(_lastFeedId).index = _index;
            delete __storage().records[feedId];
        }
        emit WitnetFeedDeleted(feedId);
    }

    function deleteFeeds()
        virtual override
        external
        onlyOwner
    {
        bytes4[] storage __ids = __storage().ids;
        for (uint _ix = __ids.length; _ix > 0; _ix --) {
            bytes4 _feedId = __ids[_ix - 1];
            delete __storage().records[_feedId]; __ids.pop();
            emit WitnetFeedDeleted(_feedId);
        }
    }

    function settleBaseFeeOverheadPercentage(uint16 _baseFeeOverheadPercentage)
        virtual override
        external
        onlyOwner 
    {
        __baseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    function settleDefaultRadonSLA(Witnet.QuerySLA calldata defaultSLA)
        override public
        onlyOwner
    {
        _require(defaultSLA.isValid(), "invalid SLA");
        __defaultRadonSLA = defaultSLA;
        emit WitnetRadonSLA(defaultSLA);
    }
    
    function settleFeedRequest(string calldata caption, bytes32 radHash)
        override public
        onlyOwner
    {
        _require(
            _registry().lookupRadonRequestResultDataType(radHash) == dataType,
            "bad result data type"
        );
        bytes4 feedId = hash(caption);
        Record storage __record = __records_(feedId);
        if (__record.index == 0) {
            // settle new feed:
            __record.caption = caption;
            __record.decimals = _validateCaption(caption);
            __record.index = __storage().ids.length + 1;
            __record.radHash = radHash;
            __storage().ids.push(feedId);
        } else if (__record.radHash != radHash) {
            // update radHash on existing feed:
            __record.radHash = radHash;
            __record.solver = address(0);
        }
        emit WitnetFeedSettled(feedId, radHash);
    }

    function settleFeedRequest(string calldata caption, WitOracleRequest request)
        override external
        onlyOwner
    {
        settleFeedRequest(caption, request.radHash());
    }

    function settleFeedRequest(
            string calldata caption,
            WitOracleRequestTemplate template,
            string[][] calldata args
        )
        override external
        onlyOwner
    {
        settleFeedRequest(caption, template.verifyRadonRequest(args));
    }

    function settleFeedSolver(
            string calldata caption,
            address solver,
            string[] calldata deps
        )
        override external
        onlyOwner
    {
        _require(
            solver != address(0),
            "no solver address"
        );
        bytes4 feedId = hash(caption);        
        Record storage __record = __records_(feedId);
        if (__record.index == 0) {
            // settle new feed:
            __record.caption = caption;
            __record.decimals = _validateCaption(caption);
            __record.index = __storage().ids.length + 1;
            __record.solver = solver;
            __storage().ids.push(feedId);
        } else if (__record.solver != solver) {
            // update radHash on existing feed:
            __record.radHash = 0;
            __record.solver = solver;
        }
        // validate solver first-level dependencies
        {
            // solhint-disable-next-line avoid-low-level-calls
            (bool _success, bytes memory _reason) = solver.delegatecall(abi.encodeWithSelector(
                IWitPriceFeedsSolver.validate.selector,
                feedId,
                deps
            ));
            if (!_success) {
                assembly {
                    _reason := add(_reason, 4)
                }
                _revert(string(abi.encodePacked(
                    "solver validation failed: ",
                    string(abi.decode(_reason,(string)))
                )));
            }
        }
        // smoke-test the solver 
        {   
            // solhint-disable-next-line avoid-low-level-calls
            (bool _success, bytes memory _reason) = address(this).staticcall(abi.encodeWithSelector(
                IWitPriceFeedsSolver.solve.selector,
                feedId
            ));
            if (!_success) {
                assembly {
                    _reason := add(_reason, 4)
                }
                _revert(string(abi.encodePacked(
                    "smoke-test failed: ",
                    string(abi.decode(_reason,(string)))
                )));
            }
        }
        emit WitnetFeedSolverSettled(feedId, solver);
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeeds' -----------------------------------------------------------------------------

    function lookupDecimals(bytes4 feedId) 
        override 
        external view
        returns (uint8)
    {
        return __records_(feedId).decimals;
    }
    
    function lookupPriceSolver(bytes4 feedId)
        override
        external view
        returns (IWitPriceFeedsSolver _solverAddress, string[] memory _solverDeps)
    {
        _solverAddress = IWitPriceFeedsSolver(__records_(feedId).solver);
        bytes4[] memory _deps = _depsOf(feedId);
        _solverDeps = new string[](_deps.length);
        for (uint _ix = 0; _ix < _deps.length; _ix ++) {
            _solverDeps[_ix] = lookupCaption(_deps[_ix]);
        }
    }

    function latestPrice(bytes4 feedId)
        virtual override
        public view
        returns (IWitPriceFeedsSolver.Price memory)
    {
        Witnet.QueryId _queryId = _lastValidQueryId(feedId);
        if (Witnet.QueryId.unwrap(_queryId) > 0) {
            Witnet.DataResult memory _lastValidResult = witOracle.getQueryResult(_queryId);
            return IWitPriceFeedsSolver.Price({
                value: _lastValidResult.fetchUint(),
                timestamp: _lastValidResult.timestamp,
                drTxHash: _lastValidResult.drTxHash,
                status: latestUpdateQueryResultStatus(feedId)
            });
        } else {
            address _solver = __records_(feedId).solver;
            if (_solver != address(0)) {
                // solhint-disable-next-line avoid-low-level-calls
                (bool _success, bytes memory _result) = address(this).staticcall(abi.encodeWithSelector(
                    IWitPriceFeedsSolver.solve.selector,
                    feedId
                ));
                if (!_success) {
                    assembly {
                        _result := add(_result, 4)
                    }
                    revert(string(abi.encodePacked(
                        "WitPriceFeeds: ",
                        string(abi.decode(_result, (string)))
                    )));
                } else {
                    return abi.decode(_result, (IWitPriceFeedsSolver.Price));
                }
            } else {
                return IWitPriceFeedsSolver.Price({
                    value: 0,
                    timestamp: Witnet.ResultTimestamp.wrap(0),
                    drTxHash: Witnet.TransactionHash.wrap(0),
                    status: latestUpdateQueryResultStatus(feedId)
                });
            }
        }
    }

    function latestPrices(bytes4[] calldata feedIds)
        virtual override
        external view
        returns (IWitPriceFeedsSolver.Price[] memory _prices)
    {
        _prices = new IWitPriceFeedsSolver.Price[](feedIds.length);
        for (uint _ix = 0; _ix < feedIds.length; _ix ++) {
            _prices[_ix] = latestPrice(feedIds[_ix]);
        }
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeedsSolverFactory' ---------------------------------------------------------------------

    function deployPriceSolver(bytes calldata initcode, bytes calldata constructorParams)
        virtual override
        external
        onlyOwner
        returns (address _solver)
    {
        _solver = WitPriceFeedsLib.deployPriceSolver(initcode, constructorParams);
        emit NewPriceFeedsSolver(
            _solver, 
            _solver.codehash, 
            constructorParams
        );
    }

    function determinePriceSolverAddress(bytes calldata initcode, bytes calldata constructorParams)
        virtual override
        public view
        returns (address _address)
    {
        return WitPriceFeedsLib.determinePriceSolverAddress(initcode, constructorParams);
    }


    // ================================================================================================================
    // --- Implements 'IERC2362' --------------------------------------------------------------------------------------
    
    function valueFor(bytes32 feedId)
        virtual override
        external view
        returns (int256 _value, uint256 _timestamp, uint256 _status)
    {
        IWitPriceFeedsSolver.Price memory _latestPrice = latestPrice(bytes4(feedId));
        return (
            int(uint(_latestPrice.value)),
            Witnet.ResultTimestamp.unwrap(_latestPrice.timestamp),
            _latestPrice.status == Witnet.ResultStatus.NoErrors
                ? 200
                : (_latestPrice.status.keepWaiting() ? 404 : 400)
        );
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _coalesceQueryResultStatus(Witnet.QueryId _queryId)
        internal view
        returns (Witnet.ResultStatus)
    {
        if (Witnet.QueryId.unwrap(_queryId) > 0) {
            return witOracle.getQueryResultStatus(_queryId);
        } else {
            return Witnet.ResultStatus.NoErrors;
        }
    }

    function _footprintOf(bytes4 _id4) virtual internal view returns (bytes4) {
        if (__records_(_id4).radHash != bytes32(0)) {
            return bytes4(keccak256(abi.encode(_id4, __records_(_id4).radHash)));
        } else {
            return bytes4(keccak256(abi.encode(_id4, __records_(_id4).solverDepsFlag)));
        }
    }

    function _lastValidQueryId(bytes4 feedId)
        virtual internal view
        returns (Witnet.QueryId _queryId)
    {
        _queryId = latestUpdateQueryId(feedId);
        if (
            Witnet.QueryId.unwrap(_queryId) == 0
                || witOracle.getQueryResultStatus(_queryId) != Witnet.ResultStatus.NoErrors 
        ) {
            _queryId = __records_(feedId).lastValidQueryId;
        }
    }

    function _validateCaption(string calldata caption)
        internal view returns (uint8)
    {
        try WitPriceFeedsLib.validateCaption(__prefix, caption) returns (uint8 _decimals) {
            return _decimals;
        } catch Error(string memory reason) {
            _revert(reason);
        }
    }

    function __requestUpdate(bytes4[] memory _deps, Witnet.QuerySLA memory sla)
        virtual internal
        returns (uint256 _usedFunds)
    {
        uint _partial = msg.value / _deps.length;
        for (uint _ix = 0; _ix < _deps.length; _ix ++) {
            _usedFunds += this.requestUpdate{value: _partial}(_deps[_ix], sla);
        }
    }

    function __requestUpdate(bytes4 feedId, Witnet.QuerySLA memory querySLA)
        virtual internal
        returns (uint256 _usedFunds)
    {
        // TODO: let requester settle the reward (see WRV2.randomize(..))
        Record storage __feed = __records_(feedId);
        if (__feed.radHash != 0) {
            _usedFunds = estimateUpdateRequestFee(tx.gasprice);
            _require(msg.value >= _usedFunds, "insufficient reward");
            Witnet.QueryId _latestId = __feed.latestUpdateQueryId;
            Witnet.ResultStatus _latestStatus = _coalesceQueryResultStatus(_latestId);
            if (_latestStatus.keepWaiting()) {
                // latest update is still pending, so just increase the reward
                // accordingly to current tx gasprice:
                uint72 _evmReward = Witnet.QueryReward.unwrap(witOracle.getQueryEvmReward(_latestId));
                int _deltaReward = int(int72(_evmReward)) - int(_usedFunds);
                if (_deltaReward > 0) {
                    _usedFunds = uint(_deltaReward);
                    witOracle.upgradeQueryEvmReward{value: _usedFunds}(_latestId);
                } else {
                    _usedFunds = 0;
                }
            } else {
                // Check if latest update ended successfully:
                if (_latestStatus == Witnet.QueryResponseStatus.Ready) {
                    // If so, remove previous last valid query from the WRB:
                    if (Witnet.QueryId.unwrap(__feed.lastValidQueryId) > 0) {
                        witOracle.fetchQueryResponse(__feed.lastValidQueryId);
                    }
                    __feed.lastValidQueryId = _latestId;
                } else {
                    // Otherwise, try to delete latest query, as it was faulty
                    // and we are about to post a new update request:
                    try witOracle.fetchQueryResponse(_latestId) {} catch {}
                }
                // Post update request to the WRB:
                _latestId = witOracle.postQuery{value: _usedFunds}(
                    __feed.radHash,
                    querySLA
                );
                // Update latest query id:
                __feed.latestUpdateQueryId = _latestId;
                // solhint-disable avoid-tx-origin:
                emit PullingUpdate(
                    tx.origin, 
                    _msgSender(),
                    feedId,
                    Witnet.QueryId.unwrap(_latestId)
                );
            }            
        } else if (__feed.solver != address(0)) {
            _usedFunds = __requestUpdate(
                _depsOf(feedId), 
                querySLA
            );
        } else {
            _revert("unknown feed");
        }
        if (_usedFunds < msg.value) {
            // transfer back unused funds:
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
    }
}
