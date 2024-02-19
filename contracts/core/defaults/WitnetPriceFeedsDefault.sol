// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetUpgradableBase.sol";

import "../../WitnetPriceFeeds.sol";

import "../../data/WitnetPriceFeedsData.sol";
import "../../libs/WitnetPriceFeedsLib.sol";
import "../../patterns/Ownable2Step.sol";

/// @title WitnetPriceFeeds: Price Feeds live repository reliant on the Witnet Oracle blockchain.
/// @author Guillermo Díaz <guillermo@otherplane.com>

contract WitnetPriceFeedsDefault
    is
        Ownable2Step,
        WitnetPriceFeeds,
        WitnetPriceFeedsData,
        WitnetUpgradableBase

{
    using Witnet for bytes;
    using Witnet for Witnet.Result;
    using WitnetV2 for WitnetV2.Response;
    using WitnetV2 for WitnetV2.RadonSLA;

    function class() virtual override external view returns (string memory) {
        return type(WitnetPriceFeedsDefault).name;
    }

    bytes4 immutable public override specs = type(IWitnetPriceFeeds).interfaceId;
    WitnetOracle immutable public override witnet;

    WitnetV2.RadonSLA private __defaultRadonSLA;
    
    constructor(
            WitnetOracle _wrb,
            bool _upgradable,
            bytes32 _versionTag
        )
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.feeds.price"
        )
    {
        witnet = _wrb;
    }

    // solhint-disable-next-line payable-fallback
    fallback() override external {
        if (
            msg.sig == IWitnetPriceSolver.solve.selector
                && msg.sender == address(this)
        ) {
            address _solver = __records_(bytes4(bytes8(msg.data) << 32)).solver;
            require(
                _solver != address(0),
                "WitnetPriceFeeds: unsettled solver"
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
            revert("WitnetPriceFeeds: not implemented");
        }
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData)
        public
        override
    {
        address _owner = owner();
        if (_owner == address(0)) {
            // set owner as specified by first argument in _initData
            _owner = abi.decode(_initData, (address));
            _transferOwnership(_owner);
            // settle default Radon SLA upon first initialization
            __defaultRadonSLA = WitnetV2.RadonSLA({
                committeeSize: 10,
                witnessingFee: 2 * 10 ** 8   // 0.2 $WIT
            });
        } else {
            // only the owner can initialize:
            require(
                msg.sender == _owner,
                "WitnetPriceFeeds: not the owner"
            );
        }

        if (
            __proxiable().codehash != bytes32(0)
                && __proxiable().codehash == codehash()
        ) {
            revert("WitnetPriceFeeds: already upgraded");
        }        
        __proxiable().codehash = codehash();

        require(
            address(witnet).code.length > 0,
            "WitnetPriceFeeds: inexistent oracle"
        );
        require(
            witnet.specs() == type(IWitnetOracle).interfaceId, 
            "WitnetPriceFeeds: uncompliant oracle"
        );
        emit Upgraded(_owner, base(), codehash(), version());
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
    // --- Implements 'IWitnetFeeds' ----------------------------------------------------------------------------------

    function defaultRadonSLA()
        override
        public view
        returns (Witnet.RadonSLA memory)
    {
        return __defaultRadonSLA.toV1();
    }
    
    function estimateUpdateBaseFee(uint256 _evmGasPrice)
        virtual override
        public view
        returns (uint)
    {
        return witnet.estimateBaseFee(_evmGasPrice, 32);
    }

    function lastValidResponse(bytes4 feedId)
        override public view
        returns (WitnetV2.Response memory)
    {
        return witnet.getQueryResponse(_lastValidQueryId(feedId));
    }


    function latestUpdateQueryId(bytes4 feedId)
        override public view
        returns (uint256)
    {
        return __records_(feedId).latestUpdateQueryId;
    }

    function latestUpdateRequest(bytes4 feedId)
        override external view 
        returns (WitnetV2.Request memory)
    {
        return witnet.getQueryRequest(latestUpdateQueryId(feedId));
    }

    function latestUpdateResponse(bytes4 feedId)
        override external view
        returns (WitnetV2.Response memory)
    {
        return witnet.getQueryResponse(latestUpdateQueryId(feedId));
    }

    function latestUpdateResultError(bytes4 feedId)
        override external view 
        returns (Witnet.ResultError memory)
    {
        return witnet.getQueryResultError(latestUpdateQueryId(feedId));
    }
    
    function latestUpdateResponseStatus(bytes4 feedId)
        override public view
        returns (WitnetV2.ResponseStatus)
    {
        return _checkQueryResponseStatus(latestUpdateQueryId(feedId));
    }

    function lookupWitnetBytecode(bytes4 feedId)
        override external view
        returns (bytes memory)
    {
        Record storage __record = __records_(feedId);
        require(
            __record.radHash != 0,
            "WitnetPriceFeeds: no RAD hash"
        );
        return registry().bytecodeOf(__record.radHash);
    }
    
    function lookupWitnetRadHash(bytes4 feedId)
        override public view
        returns (bytes32)
    {
        return __records_(feedId).radHash;
    }

    function lookupWitnetRetrievals(bytes4 feedId)
        override external view
        returns (Witnet.RadonRetrieval[] memory _retrievals)
    {
        bytes32[] memory _hashes = registry().lookupRadonRequestSources(lookupWitnetRadHash(feedId));
        _retrievals = new Witnet.RadonRetrieval[](_hashes.length);
        for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
            _retrievals[_ix] = registry().lookupRadonRetrieval(_hashes[_ix]);
        }
    }

    function registry() public view virtual override returns (WitnetRequestBytecodes) {
        return WitnetOracle(address(witnet)).registry();
    }

    function requestUpdate(bytes4 feedId)
        external payable
        virtual override
        returns (uint256)
    {
        return __requestUpdate(feedId, __defaultRadonSLA);
    }
    
    function requestUpdate(bytes4 feedId, WitnetV2.RadonSLA calldata updateSLA)
        public payable
        virtual override
        returns (uint256 _usedFunds)
    {
        require(
            updateSLA.equalOrGreaterThan(__defaultRadonSLA),
            "WitnetPriceFeeds: unsecure update"
        );
        return __requestUpdate(feedId, updateSLA);
    }


    // ================================================================================================================
    // --- Implements 'IWitnetFeedsAdmin' -----------------------------------------------------------------------------

    function owner()
        virtual override (IWitnetFeedsAdmin, Ownable)
        public view 
        returns (address)
    {
        return Ownable.owner();
    }
    
    function acceptOwnership()
        virtual override (IWitnetFeedsAdmin, Ownable2Step)
        public
    {
        Ownable2Step.acceptOwnership();
    }

    function pendingOwner() 
        virtual override (IWitnetFeedsAdmin, Ownable2Step)
        public view
        returns (address)
    {
        return Ownable2Step.pendingOwner();
    }
    
    function transferOwnership(address _newOwner)
        virtual override (IWitnetFeedsAdmin, Ownable2Step)
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
        require(_index != 0, "WitnetPriceFeeds: unknown feed");
        {
            bytes4 _lastFeedId = __ids[__ids.length - 1];
            __ids[_index - 1] = _lastFeedId;
            __records_(_lastFeedId).index = _index;
            delete __storage().records[feedId];
        }
        emit DeletedFeed(msg.sender, feedId, caption);
    }

    function settleDefaultRadonSLA(WitnetV2.RadonSLA calldata defaultSLA)
        override public
        onlyOwner
    {
        require(defaultSLA.isValid(), "WitnetPriceFeeds: invalid SLA");
        __defaultRadonSLA = defaultSLA;
    }
    
    function settleFeedRequest(string calldata caption, bytes32 radHash)
        override public
        onlyOwner
    {
        require(
            registry().lookupRadonRequestResultDataType(radHash) == dataType,
            "WitnetPriceFeeds: bad result data type"
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
        emit SettledFeed(msg.sender, feedId, caption, radHash);
    }

    function settleFeedRequest(string calldata caption, WitnetRequest request)
        override external
        onlyOwner
    {
        settleFeedRequest(caption, request.radHash());
    }

    function settleFeedRequest(
            string calldata caption,
            WitnetRequestTemplate template,
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
        require(
            solver != address(0),
            "WitnetPriceFeeds: no solver address"
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
                IWitnetPriceSolver.validate.selector,
                feedId,
                deps
            ));
            if (!_success) {
                assembly {
                    _reason := add(_reason, 4)
                }
                revert(string(abi.encodePacked(
                    "WitnetPriceFeedUpgradable: solver validation failed: ",
                    string(abi.decode(_reason,(string)))
                )));
            }
        }
        // smoke-test the solver 
        {   
            // solhint-disable-next-line avoid-low-level-calls
            (bool _success, bytes memory _reason) = address(this).staticcall(abi.encodeWithSelector(
                IWitnetPriceSolver.solve.selector,
                feedId
            ));
            if (!_success) {
                assembly {
                    _reason := add(_reason, 4)
                }
                revert(string(abi.encodePacked(
                    "WitnetPriceFeeds: smoke-test failed: ",
                    string(abi.decode(_reason,(string)))
                )));
            }
        }
        emit SettledFeedSolver(msg.sender, feedId, caption, solver);
    }


    // ================================================================================================================
    // --- Implements 'IWitnetPriceFeeds' -----------------------------------------------------------------------------

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
        returns (IWitnetPriceSolver _solverAddress, string[] memory _solverDeps)
    {
        _solverAddress = IWitnetPriceSolver(__records_(feedId).solver);
        bytes4[] memory _deps = _depsOf(feedId);
        _solverDeps = new string[](_deps.length);
        for (uint _ix = 0; _ix < _deps.length; _ix ++) {
            _solverDeps[_ix] = lookupCaption(_deps[_ix]);
        }
    }

    function latestPrice(bytes4 feedId)
        virtual override
        public view
        returns (IWitnetPriceSolver.Price memory)
    {
        uint _queryId = _lastValidQueryId(feedId);
        if (_queryId > 0) {
            WitnetV2.Response memory _lastValidResponse = lastValidResponse(feedId);
            Witnet.Result memory _latestResult = _lastValidResponse.resultCborBytes.toWitnetResult();
            return IWitnetPriceSolver.Price({
                value: _latestResult.asUint(),
                timestamp: _lastValidResponse.resultTimestamp,
                tallyHash: _lastValidResponse.resultTallyHash,
                status: latestUpdateResponseStatus(feedId)
            });
        } else {
            address _solver = __records_(feedId).solver;
            if (_solver != address(0)) {
                // solhint-disable-next-line avoid-low-level-calls
                (bool _success, bytes memory _result) = address(this).staticcall(abi.encodeWithSelector(
                    IWitnetPriceSolver.solve.selector,
                    feedId
                ));
                if (!_success) {
                    assembly {
                        _result := add(_result, 4)
                    }
                    revert(string(abi.encodePacked(
                        "WitnetPriceFeeds: ",
                        string(abi.decode(_result, (string)))
                    )));
                } else {
                    return abi.decode(_result, (IWitnetPriceSolver.Price));
                }
            } else {
                return IWitnetPriceSolver.Price({
                    value: 0,
                    timestamp: 0,
                    tallyHash: 0,
                    status: latestUpdateResponseStatus(feedId)
                });
            }
        }
    }

    function latestPrices(bytes4[] calldata feedIds)
        virtual override
        external view
        returns (IWitnetPriceSolver.Price[] memory _prices)
    {
        _prices = new IWitnetPriceSolver.Price[](feedIds.length);
        for (uint _ix = 0; _ix < feedIds.length; _ix ++) {
            _prices[_ix] = latestPrice(feedIds[_ix]);
        }
    }


    // ================================================================================================================
    // --- Implements 'IWitnetPriceSolverDeployer' ---------------------------------------------------------------------

    function deployPriceSolver(bytes calldata initcode, bytes calldata constructorParams)
        virtual override
        external
        onlyOwner
        returns (address _solver)
    {
        _solver = WitnetPriceFeedsLib.deployPriceSolver(initcode, constructorParams);
        emit WitnetPriceSolverDeployed(
            msg.sender, 
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
        return WitnetPriceFeedsLib.determinePriceSolverAddress(initcode, constructorParams);
    }


    // ================================================================================================================
    // --- Implements 'IERC2362' --------------------------------------------------------------------------------------
    
    function valueFor(bytes32 feedId)
        virtual override
        external view
        returns (int256 _value, uint256 _timestamp, uint256 _status)
    {
        IWitnetPriceSolver.Price memory _latestPrice = latestPrice(bytes4(feedId));
        return (
            int(_latestPrice.value),
            _latestPrice.timestamp,
            _latestPrice.status == WitnetV2.ResponseStatus.Ready 
                ? 200
                : (
                    _latestPrice.status == WitnetV2.ResponseStatus.Awaiting 
                        || _latestPrice.status == WitnetV2.ResponseStatus.AwaitingReady
                        || _latestPrice.status == WitnetV2.ResponseStatus.AwaitingError
                ) ? 404 : 400
        );
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _checkQueryResponseStatus(uint _queryId)
        internal view
        returns (WitnetV2.ResponseStatus)
    {
        if (_queryId > 0) {
            return witnet.getQueryResponseStatus(_queryId);
        } else {
            return WitnetV2.ResponseStatus.Ready;
        }
    }

    function _lastValidQueryId(bytes4 feedId)
        virtual internal view
        returns (uint256)
    {
        uint _latestUpdateQueryId = latestUpdateQueryId(feedId);
        if (
            _latestUpdateQueryId > 0
                && witnet.getQueryResponseStatus(_latestUpdateQueryId) == WitnetV2.ResponseStatus.Ready
        ) {
            return _latestUpdateQueryId;
        } else {
            return __records_(feedId).lastValidQueryId;
        }
    }

    function _validateCaption(string calldata caption)
        internal view returns (uint8)
    {
        try WitnetPriceFeedsLib.validateCaption(__prefix, caption) returns (uint8 _decimals) {
            return _decimals;
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked(
                "WitnetPriceFeeds: ", 
                reason
            )));
        }
    }

    function __requestUpdate(bytes4[] memory _deps, WitnetV2.RadonSLA memory sla)
        virtual internal
        returns (uint256 _usedFunds)
    {
        uint _partial = msg.value / _deps.length;
        for (uint _ix = 0; _ix < _deps.length; _ix ++) {
            _usedFunds += this.requestUpdate{value: _partial}(_deps[_ix], sla);
        }
    }

    function __requestUpdate(bytes4 feedId, WitnetV2.RadonSLA memory querySLA)
        virtual internal
        returns (uint256 _usedFunds)
    {
        Record storage __feed = __records_(feedId);
        if (__feed.radHash != 0) {
            _usedFunds = estimateUpdateBaseFee(tx.gasprice);
            require(
                msg.value >= _usedFunds, 
                "WitnetPriceFeeds: insufficient reward"
            );
            uint _latestId = __feed.latestUpdateQueryId;
            WitnetV2.ResponseStatus _latestStatus = _checkQueryResponseStatus(_latestId);
            if (_latestStatus == WitnetV2.ResponseStatus.Awaiting) {
                // latest update is still pending, so just increase the reward
                // accordingly to current tx gasprice:
                int _deltaReward = int(witnet.getQueryEvmReward(_latestId)) - int(_usedFunds);
                if (_deltaReward > 0) {
                    _usedFunds = uint(_deltaReward);
                    witnet.upgradeQueryEvmReward{value: _usedFunds}(_latestId);
                    // solhint-disable avoid-tx-origin
                    emit UpdateRequestReward(
                        tx.origin, 
                        feedId, 
                        _latestId,
                        _usedFunds
                    );
                } else {
                    _usedFunds = 0;
                }
            } else {
                // Check if latest update ended successfully:
                if (_latestStatus == WitnetV2.ResponseStatus.Ready) {
                    // If so, remove previous last valid query from the WRB:
                    if (__feed.lastValidQueryId > 0) {
                        witnet.fetchQueryResponse(__feed.lastValidQueryId);
                    }
                    __feed.lastValidQueryId = _latestId;
                } else {
                    // Otherwise, try to delete latest query, as it was faulty
                    // and we are about to post a new update request:
                    try witnet.fetchQueryResponse(_latestId) {} catch {}
                }
                // Post update request to the WRB:
                _latestId = witnet.postRequest{value: _usedFunds}(
                    __feed.radHash,
                    querySLA
                );
                // Update latest query id:
                __feed.latestUpdateQueryId = _latestId;
                // solhint-disable avoid-tx-origin:
                emit UpdateRequest(
                    tx.origin, 
                    feedId,
                    _latestId,
                    _usedFunds,
                    querySLA
                );
            }            
        } else if (__feed.solver != address(0)) {
            _usedFunds = __requestUpdate(
                _depsOf(feedId), 
                querySLA
            );
        } else {
            revert("WitnetPriceFeeds: unknown feed");
        }
        if (_usedFunds < msg.value) {
            // transfer back unused funds:
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
    }

}
