// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../WitPriceFeeds.sol";
import "../core/WitnetUpgradableBase.sol";

import "../data/WitPriceFeedsDataLib.sol";

import "../interfaces/IWitFeedsAdmin.sol";
import "../interfaces/IWitFeedsLegacy.sol";
import "../interfaces/IWitPriceFeedsSolverFactory.sol";
import "../interfaces/IWitOracleLegacy.sol";

import "../patterns/Ownable2Step.sol";

/// @title WitPriceFeeds: Price Feeds live repository reliant on the Wit/oracle blockchain.
/// @author Guillermo Díaz <guillermo@otherplane.com>

contract WitPriceFeedsUpgradable
    is
        Ownable2Step,
        WitPriceFeeds,
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
            address _solver = WitPriceFeedsDataLib.seekRecord(bytes4(bytes8(msg.data) << 32)).solver;
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
            } else if (!__defaultRadonSLA.isValid()) {
                // possibly, an upgrade from a previous branch took place:
                __defaultRadonSLA = Witnet.QuerySLA({
                    witCommitteeCapacity: 10,
                    witCommitteeUnitaryReward: 2 * 10 ** 8,
                    witResultMaxSize: 16,
                    witCapability: Witnet.QueryCapability.wrap(0)
                });
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
    // --- Implements 'IWitFeeds' -------------------------------------------------------------------------------------

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
        return WitPriceFeedsDataLib.hash(caption);
    }

    function lookupCaption(bytes4 feedId)
        override
        public view
        returns (string memory)
    {
        return WitPriceFeedsDataLib.seekRecord(feedId).caption;
    }

    function supportedFeeds()
        virtual override
        external view
        returns (bytes4[] memory _ids, string[] memory _captions, bytes32[] memory _solvers)
    {
        return WitPriceFeedsDataLib.supportedFeeds();
    }
    
    function supportsCaption(string calldata caption)
        virtual override
        external view
        returns (bool)
    {
        bytes4 feedId = hash(caption);
        return hash(WitPriceFeedsDataLib.seekRecord(feedId).caption) == feedId;
    }
    
    function totalFeeds() 
        override 
        external view
        returns (uint256)
    {
        return __storage().ids.length;
    }

    function lastValidQueryId(bytes4 feedId)
        override public view
        returns (Witnet.QueryId)
    {
        return WitPriceFeedsDataLib.lastValidQueryId(witOracle, feedId);
    }

    function lastValidQueryResponse(bytes4 feedId)
        override public view
        returns (Witnet.QueryResponse memory)
    {
        return witOracle.getQueryResponse(
            WitPriceFeedsDataLib.lastValidQueryId(witOracle, feedId)
        );
    }

    function latestUpdateQueryId(bytes4 feedId)
        override public view
        returns (Witnet.QueryId)
    {
        return WitPriceFeedsDataLib.seekRecord(feedId).latestUpdateQueryId;
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
        return WitPriceFeedsDataLib.latestUpdateQueryResultStatus(witOracle, feedId);
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
        WitPriceFeedsDataLib.Record storage __record = WitPriceFeedsDataLib.seekRecord(feedId);
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
        return WitPriceFeedsDataLib.seekRecord(feedId).radHash;
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
        returns (uint256)
    {
        _require(
            updateSLA.equalOrGreaterThan(__defaultRadonSLA),
            "unsecure update request"
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

    function deleteFeed(string calldata caption) virtual override external onlyOwner {
        try WitPriceFeedsDataLib.deleteFeed(caption) {
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertWitPriceFeedsDataLibUnhandledException();
        }
    }

    function deleteFeeds() virtual override external onlyOwner {
        try WitPriceFeedsDataLib.deleteFeeds() {
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertWitPriceFeedsDataLibUnhandledException();
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
    }
    
    function settleFeedRequest(string calldata caption, bytes32 radHash)
        override public
        onlyOwner
    {
        _require(
            _registry().lookupRadonRequestResultDataType(radHash) == dataType,
            "bad result data type"
        );
        try WitPriceFeedsDataLib.settleFeedRequest(caption, radHash) {

        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitPriceFeedsDataLibUnhandledException();
        }
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
            bytes6(bytes(caption)) == bytes6(__prefix),
            "bad caption prefix"
        );
        _require(
            solver != address(0),
            "no solver address"
        );
        try WitPriceFeedsDataLib.settleFeedSolver(caption, solver, deps) {
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitPriceFeedsDataLibUnhandledException();
        }
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeeds' -----------------------------------------------------------------------------

    function lookupDecimals(bytes4 feedId) 
        override 
        external view
        returns (uint8)
    {
        return WitPriceFeedsDataLib.seekRecord(feedId).decimals;
    }
    
    function lookupPriceSolver(bytes4 feedId)
        override
        external view
        returns (IWitPriceFeedsSolver _solverAddress, string[] memory _solverDeps)
    {
        return WitPriceFeedsDataLib.seekPriceSolver(feedId);
    }

    function latestPrice(bytes4 feedId)
        virtual override
        public view
        returns (IWitPriceFeedsSolver.Price memory)
    {
        try WitPriceFeedsDataLib.latestPrice(
            witOracle, 
            feedId
        ) returns (IWitPriceFeedsSolver.Price memory _latestPrice) {
            return _latestPrice;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitPriceFeedsDataLibUnhandledException();
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
        virtual override external
        onlyOwner
        returns (address)
    {
        try WitPriceFeedsDataLib.deployPriceSolver(
            initcode, 
            constructorParams
        ) returns (
            address _solver
        ) {
            emit NewPriceFeedsSolver(
                _solver, 
                _solver.codehash, 
                constructorParams
            );
            return _solver;
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertWitPriceFeedsDataLibUnhandledException();
        }
    }

    function determinePriceSolverAddress(bytes calldata initcode, bytes calldata constructorParams)
        virtual override public view
        returns (address _address)
    {
        return WitPriceFeedsDataLib.determinePriceSolverAddress(initcode, constructorParams);
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
            (_latestPrice.latestStatus == IWitPriceFeedsSolver.LatestUpdateStatus.Ready
                ? 200
                : (_latestPrice.latestStatus == IWitPriceFeedsSolver.LatestUpdateStatus.Awaiting
                    ? 404 
                    : 400
                )
            )
        );
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _footprintOf(bytes4 _id4) virtual internal view returns (bytes4) {
        if (WitPriceFeedsDataLib.seekRecord(_id4).radHash != bytes32(0)) {
            return bytes4(keccak256(abi.encode(_id4, WitPriceFeedsDataLib.seekRecord(_id4).radHash)));
        } else {
            return bytes4(keccak256(abi.encode(_id4, WitPriceFeedsDataLib.seekRecord(_id4).solverDepsFlag)));
        }
    }

    function _validateCaption(string calldata caption)
        internal view returns (uint8)
    {
        _require(
            bytes6(bytes(caption)) == bytes6(__prefix),
            "bad caption prefix"
        );
        try WitPriceFeedsDataLib.validateCaption(caption) returns (uint8 _decimals) {
            return _decimals;
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertWitPriceFeedsDataLibUnhandledException();
        }
    }

    function _revertWitPriceFeedsDataLibUnhandledException() internal view {
        _revert(_revertWitPriceFeedsDataLibUnhandledExceptionReason());
    }

    function _revertWitPriceFeedsDataLibUnhandledExceptionReason() internal pure returns (string memory) {
        return string(abi.encodePacked(
            type(WitPriceFeedsDataLib).name,
            ": unhandled assertion"
        ));
    }

    function __requestUpdate(bytes4[] memory _deps, Witnet.QuerySLA memory sla)
        virtual internal
        returns (uint256 _evmUsedFunds)
    {
        uint _evmUnitaryUpdateRequestFee = msg.value / _deps.length;
        for (uint _ix = 0; _ix < _deps.length; _ix ++) {
            _evmUsedFunds += this.requestUpdate{
                value: _evmUnitaryUpdateRequestFee
            }(
                _deps[_ix], 
                sla
            );
        }
    }

    function __requestUpdate(
            bytes4 feedId, 
            Witnet.QuerySLA memory querySLA
        )
        virtual internal
        returns (uint256)
    {
        if (WitPriceFeedsDataLib.seekRecord(feedId).radHash != 0) {
            uint256 _evmUpdateRequestFee = msg.value;
            try WitPriceFeedsDataLib.requestUpdate(
                witOracle,
                feedId,
                querySLA,
                _evmUpdateRequestFee
            
            ) returns (
                Witnet.QueryId _latestQueryId,
                uint256 _evmUsedFunds
            
            ) {
                if (_evmUsedFunds < msg.value) {
                    // transfer back unused funds:
                    payable(msg.sender).transfer(msg.value - _evmUsedFunds);
                }
                // solhint-disable avoid-tx-origin:
                emit PullingUpdate(tx.origin, _msgSender(), feedId, _latestQueryId);
                return _evmUsedFunds;
            
            } catch Error(string memory _reason) {
                _revert(_reason);

            } catch (bytes memory) {
                _revertWitPriceFeedsDataLibUnhandledException();
            }
        
        } else if (WitPriceFeedsDataLib.seekRecord(feedId).solver != address(0)) {
            return __requestUpdate(
                WitPriceFeedsDataLib.depsOf(feedId),
                querySLA
            );

        } else {
            _revert("unknown feed");
        }
    }

    function __storage() internal pure returns (WitPriceFeedsDataLib.Storage storage) {
        return WitPriceFeedsDataLib.data();
    }
}
