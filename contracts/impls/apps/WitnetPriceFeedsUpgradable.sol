// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../WitnetPriceFeeds.sol";
import "../../data/WitnetPriceFeedsData.sol";
import "../../impls/WitnetUpgradableBase.sol";

import "../../interfaces/V2/IWitnetPriceSolver.sol";
import "../../libs/WitnetPriceFeedsLib.sol";

/// @title WitnetPriceFeedsUpgradable: ...
/// @author Witnet Foundation.
contract WitnetPriceFeedsUpgradable
    is
        WitnetPriceFeeds,
        WitnetPriceFeedsData,
        WitnetUpgradableBase
{
    using Witnet for Witnet.RadonSLA;
    using Witnet for Witnet.Result;
    
    constructor(
            WitnetRequestBoard _wrb,
            bool _upgradable,
            bytes32 _version
        )
        WitnetPriceFeeds(_wrb)
        WitnetUpgradableBase(
            _upgradable,
            _version,
            "io.witnet.proxiable.router"
        )
    {
        settleDefaultRadonSLA(Witnet.RadonSLA({
            numWitnesses: 5,
            witnessCollateral: 20 * 10 ** 9,
            witnessReward: 2 * 10 ** 8,
            minerCommitRevealFee: 10 ** 7,
            minConsensusPercentage: 51
        }));
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
                "WitnetPriceFeedsUpgradable: unsettled solver"
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
            revert("WitnetPriceFeedsUpgradable: not implemented");
        }
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory) 
        public override
        onlyDelegateCalls // => we don't want the logic base contract to be ever initialized
    {
        if (
            __proxiable().proxy == address(0)
                && __proxiable().implementation == address(0)
        ) {
            // a proxy is being initialized for the first time...
            __proxiable().proxy = address(this);
            _transferOwnership(msg.sender);
        } else {
            // only the owner can initialize:
            if (msg.sender != owner()) {
                revert("WitnetPriceFeedsUpgradable: not the owner");
            }
        }
        require(
            __proxiable().implementation != base(),
            "WitnetPriceFeedsUpgradable: already initialized"
        );
        if (__storage().defaultSlaHash == 0) {
            settleDefaultRadonSLA(Witnet.RadonSLA({
                numWitnesses: 5,
                witnessCollateral: 20 * 10 ** 9,
                witnessReward: 2 * 10 ** 8,
                minerCommitRevealFee: 10 ** 7,
                minConsensusPercentage: 51
            }));
        }
        __proxiable().implementation = base();
        emit Upgraded(msg.sender, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from)
        override
        external view
        returns (bool)
    {
        return (
            // false if the contract is set as not upgradable, or `_from` is not the owner
            isUpgradable()
                && _from == owner()
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
        return registry.lookupRadonSLA(__storage().defaultSlaHash);
    }
    
    function estimateUpdateBaseFee(bytes4, uint256 _evmGasPrice, uint256)
        virtual override
        public view
        returns (uint)
    {
        // TODO: refactor when WRB.estimateBaseFee(bytes32,bytes32,uint256,uint256) is implemented.
        return witnet.estimateReward(_evmGasPrice);
    }
    
    function estimateUpdateBaseFee(bytes4, uint256 _evmGasPrice, uint256, bytes32)
        virtual override
        public view
        returns (uint)
    {
        // TODO: refactor when WRB.estimateBaseFee(bytes32,bytes32,uint256,uint256) is implemented.
        return witnet.estimateReward(_evmGasPrice);
    }

    function latestResponse(bytes4 feedId)
        override public view
        returns (Witnet.Response memory)
    {
        return witnet.readResponse(_latestValidQueryId(feedId));
    }
    
    function latestResult(bytes4 feedId)
        override external view
        returns (Witnet.Result memory)
    {
        return witnet.readResponseResult(_latestValidQueryId(feedId));
    }

    function latestUpdateQueryId(bytes4 feedId)
        override public view
        returns (uint256)
    {
        return __records_(feedId).latestUpdateQueryId;
    }

    function latestUpdateRequest(bytes4 feedId)
        override external view 
        returns (Witnet.Request memory)
    {
        return witnet.readRequest(latestUpdateQueryId(feedId));
    }

    function latestUpdateResponse(bytes4 feedId)
        override external view
        returns (Witnet.Response memory)
    {
        return witnet.readResponse(latestUpdateQueryId(feedId));
    }

    function latestUpdateResultError(bytes4 feedId)
        override external view 
        returns (Witnet.ResultError memory)
    {
        return witnet.checkResultError(latestUpdateQueryId(feedId));
    }
    
    function latestUpdateResultStatus(bytes4 feedId)
        override public view
        returns (Witnet.ResultStatus)
    {
        return _checkQueryResultStatus(latestUpdateQueryId(feedId));
    }

    function lookupBytecode(bytes4 feedId)
        override external view
        returns (bytes memory)
    {
        Record storage __record = __records_(feedId);
        require(
            __record.radHash != 0,
            "WitnetPriceFeedsUpgradable: no RAD hash"
        );
        return registry.bytecodeOf(
            __record.radHash,
            __storage().defaultSlaHash
        );
    }
    
    function lookupRadHash(bytes4 feedId)
        override public view
        returns (bytes32)
    {
        return __records_(feedId).radHash;
    }

    function lookupRetrievals(bytes4 feedId)
        override external view
        returns (Witnet.RadonRetrieval[] memory _retrievals)
    {
        bytes32[] memory _hashes = registry.lookupRadonRequestSources(lookupRadHash(feedId));
        _retrievals = new Witnet.RadonRetrieval[](_hashes.length);
        for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
            _retrievals[_ix] = registry.lookupRadonRetrieval(_hashes[_ix]);
        }
    }

    function requestUpdate(bytes4 feedId)
        external payable
        virtual override
        returns (uint256)
    {
        return _requestUpdate(feedId, __storage().defaultSlaHash);
    }
    
    function requestUpdate(bytes4 feedId, bytes32 _slaHash)
        public payable
        virtual override
        returns (uint256 _usedFunds)
    {
        require(
            registry.lookupRadonSLA(_slaHash).equalOrGreaterThan(defaultRadonSLA()),
            "WitnetPriceFeedsUpgradable: unsecure update"
        );
        return _requestUpdate(feedId, _slaHash);
    }

    function _requestUpdate(bytes4[] memory _deps, bytes32 slaHash)
        virtual internal
        returns (uint256 _usedFunds)
    {
        uint _partial = msg.value / _deps.length;
        for (uint _ix = 0; _ix < _deps.length; _ix ++) {
            _usedFunds += this.requestUpdate{value: _partial}(_deps[_ix], slaHash);
        }
    }

    function _requestUpdate(bytes4 feedId, bytes32 _slaHash)
        virtual internal
        returns (uint256 _usedFunds)
    {
        Record storage __feed = __records_(feedId);
        if (__feed.radHash != 0) {
            _usedFunds = estimateUpdateBaseFee(feedId, tx.gasprice, 0, _slaHash);
            require(msg.value>= _usedFunds, "WitnetPriceFeedsUpgradable: reward too low");
            uint _latestId = __feed.latestUpdateQueryId;
            Witnet.ResultStatus _latestStatus = _checkQueryResultStatus(_latestId);
            if (_latestStatus == Witnet.ResultStatus.Awaiting) {
                // latest update is still pending, so just increase the reward
                // accordingly to current tx gasprice:
                int _deltaReward = int(witnet.readRequestReward(_latestId)) - int(_usedFunds);
                if (_deltaReward > 0) {
                    _usedFunds = uint(_deltaReward);
                    witnet.upgradeReward{value: _usedFunds}(_latestId);
                    emit UpdatingFeedReward(msg.sender, feedId, _usedFunds);
                } else {
                    _usedFunds = 0;
                }
            } else {
                // Check if latest update ended successfully:
                if (_latestStatus == Witnet.ResultStatus.Ready) {
                    // If so, remove previous last valid query from the WRB:
                    if (__feed.latestValidQueryId > 0) {
                        witnet.deleteQuery(__feed.latestValidQueryId);
                    }
                    __feed.latestValidQueryId = _latestId;
                } else {
                    // Otherwise, try to delete latest query, as it was faulty
                    // and we are about to post a new update request:
                    try witnet.deleteQuery(_latestId) {} catch {}
                }
                // Post update request to the WRB:
                _latestId = witnet.postRequest{value: _usedFunds}(__feed.radHash, _slaHash);
                // Update latest query id:
                __feed.latestUpdateQueryId = _latestId;
                emit UpdatingFeed(msg.sender, feedId, _slaHash, _usedFunds);
            }            
        } else if (__feed.solver != address(0)) {
            _usedFunds = _requestUpdate(_depsOf(feedId), _slaHash);
        } else {
            revert("WitnetPriceFeedsUpgradable: unknown feed");
        }
        if (_usedFunds < msg.value) {
            // transfer back unused funds:
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
    }


    // ================================================================================================================
    // --- Implements 'IWitnetFeedsAdmin' -----------------------------------------------------------------------

    function deleteFeed(string calldata caption)
        virtual override
        external 
        onlyOwner
    {
        bytes4 feedId = hash(caption);
        bytes4[] storage __ids = __storage().ids;
        Record storage __record = __records_(feedId);
        uint _index = __record.index;
        require(_index != 0, "WitnetPriceFeedsUpgradable: unknown feed");
        {
            bytes4 _lastFeedId = __ids[__ids.length - 1];
            __ids[_index - 1] = _lastFeedId;
            __records_(_lastFeedId).index = _index;
            delete __storage().records[feedId];
        }
        emit DeletedFeed(msg.sender, feedId, caption);
    }

    function settleDefaultRadonSLA(Witnet.RadonSLA memory sla)
        override public
        onlyOwner
    {
        __storage().defaultSlaHash = registry.verifyRadonSLA(sla);
    }
    
    function settleFeedRequest(string calldata caption, bytes32 radHash)
        override public
        onlyOwner
    {
        require(
            registry.lookupRadonRequestResultDataType(radHash) == dataType,
            "WitnetPriceFeedsUpgradable: bad result data type"
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
            "WitnetPriceFeedsUpgradable: no solver address"
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
                    "WitnetPriceFeedsUpgradable: smoke-test failed: ",
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
        uint _queryId = _latestValidQueryId(feedId);
        if (_queryId > 0) {
            Witnet.Response memory _latestResponse = latestResponse(feedId);
            Witnet.Result memory _latestResult = Witnet.resultFromCborBytes(_latestResponse.cborBytes);
            return IWitnetPriceSolver.Price({
                value: _latestResult.asUint(),
                timestamp: _latestResponse.timestamp,
                drTxHash: _latestResponse.drTxHash,
                status: latestUpdateResultStatus(feedId)
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
                        "WitnetPriceFeedsUpgradable: ",
                        string(abi.decode(_result, (string)))
                    )));
                } else {
                    return abi.decode(_result, (IWitnetPriceSolver.Price));
                }
            } else {
                return IWitnetPriceSolver.Price({
                    value: 0,
                    timestamp: 0,
                    drTxHash: 0,
                    status: latestUpdateResultStatus(feedId)
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
            _latestPrice.status == Witnet.ResultStatus.Ready 
                ? 200
                : _latestPrice.status == Witnet.ResultStatus.Awaiting 
                    ? 404
                    : 400
        );
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _checkQueryResultStatus(uint _queryId)
        internal view
        returns (Witnet.ResultStatus)
    {
        if (_queryId > 0) {
            return witnet.checkResultStatus(_queryId);
        } else {
            return Witnet.ResultStatus.Ready;
        }
    }

    function _latestValidQueryId(bytes4 feedId)
        virtual internal view
        returns (uint256)
    {
        uint _latestUpdateQueryId = latestUpdateQueryId(feedId);
        if (
            _latestUpdateQueryId > 0
                && witnet.checkResultStatus(_latestUpdateQueryId) == Witnet.ResultStatus.Ready
        ) {
            return _latestUpdateQueryId;
        } else {
            return __records_(feedId).latestValidQueryId;
        }
    }

    function _validateCaption(string calldata caption)
        internal view returns (uint8)
    {
        try WitnetPriceFeedsLib.validateCaption(__prefix, caption) returns (uint8 _decimals) {
            return _decimals;
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked(
                "WitnetPriceFeedsUpgradable: ", 
                reason
            )));
        }
    }
}
