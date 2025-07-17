// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../WitPriceFeedsLegacy.sol";

import "../core/WitnetUpgradableBase.sol";
import "../data/WitPriceFeedsLegacyDataLib.sol";
import "../interfaces/legacy/IWitOracleLegacy.sol";
import "../patterns/Ownable2Step.sol";

/// @title WitPriceFeeds: Price Feeds upgradable repository reliant on the Wit/Oracle blockchain.
/// @author Guillermo Díaz <guillermo@witnet.io>

contract WitPriceFeedsLegacyUpgradable
    is
        WitPriceFeedsLegacy,
        Ownable2Step,
        WitnetUpgradableBase
{
    using Witnet for bytes;
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.QueryResponse;
    using Witnet for Witnet.QuerySLA;
    using Witnet for Witnet.ResultStatus;

    function class() virtual override public view returns (string memory) {
        return type(WitPriceFeedsLegacyUpgradable).name;
    }

    address immutable public override witOracle;
    IWitOracleRadonRegistry immutable internal __registry;

    Witnet.QuerySLA private __defaultQuerySLA;
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
                type(IWitOracle).interfaceId
                    ^ type(IWitOracleQueriable).interfaceId
            ), "uncompliant oracle"
        );
        witOracle = address(_witOracle);
    }

    function _registry() virtual internal view returns (IWitOracleRadonRegistry) {
        return IWitOracle(witOracle).registry();
    }

    // solhint-disable-next-line payable-fallback
    fallback() override external {
        if (
            msg.sig == IWitPriceFeedsLegacySolver.solve.selector
                && msg.sender == address(this)
        ) {
            address _solver = WitPriceFeedsLegacyDataLib.seekRecord(bytes4(bytes8(msg.data) << 32)).solver;
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
            __defaultQuerySLA = Witnet.QuerySLA({
                witCommitteeSize: 10,
                witUnitaryReward: 2 * 10 ** 8,
                witResultMaxSize: 16
            });
            // settle default base fee overhead percentage
            __baseFeeOverheadPercentage = 10;
        
        } else {
            // otherwise, store beacon read from _initData, if any
            if (_initData.length > 0) {
                (uint16 _baseFeeOverheadPercentage, Witnet.QuerySLA memory _defaultQuerySLA) = abi.decode(
                    _initData, (uint16, Witnet.QuerySLA)
                );
                __baseFeeOverheadPercentage = _baseFeeOverheadPercentage;
                __defaultQuerySLA = _defaultQuerySLA;
            
            } else if (!__defaultQuerySLA.isValid()) {
                // possibly, an upgrade from a previous branch took place:
                __defaultQuerySLA = Witnet.QuerySLA({
                    witCommitteeSize: 10,
                    witUnitaryReward: 2_000_000_000, 
                    witResultMaxSize: 16
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

    // function defaultUpdateSLA()
    //     override
    //     public view
    //     returns (IWitPriceFeedsLegacy.RadonSLA memory)
    // {
    //     return IWitPriceFeedsLegacy.RadonSLA({
    //         witCommitteeSize: __defaultQuerySLA.witCommitteeSize,
    //         witUnitaryReward: __defaultQuerySLA.witUnitaryReward
    //     });
    // }

    function estimateUpdateBaseFee(uint256 _evmGasPrice) virtual override public view returns (uint256) {
        return _estimateUpdateRequestFee(_evmGasPrice);
    }
    
    function _estimateUpdateRequestFee(uint256 _evmGasPrice) internal view returns (uint) {
        return (
            IWitOracleQueriable(witOracle).estimateBaseFee(_evmGasPrice)
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
        return WitPriceFeedsLegacyDataLib.hash(caption);
    }

    function lookupCaption(bytes4 feedId)
        override
        public view
        returns (string memory)
    {
        return WitPriceFeedsLegacyDataLib.seekRecord(feedId).caption;
    }

    function supportedFeeds()
        virtual override
        external view
        returns (bytes4[] memory _ids, string[] memory _captions, bytes32[] memory _solvers)
    {
        return WitPriceFeedsLegacyDataLib.supportedFeeds();
    }
    
    function supportsCaption(string calldata caption)
        virtual override
        external view
        returns (bool)
    {
        bytes4 feedId = hash(caption);
        return hash(WitPriceFeedsLegacyDataLib.seekRecord(feedId).caption) == feedId;
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
        returns (uint256)
    {
        return WitPriceFeedsLegacyDataLib.lastValidQueryId(IWitOracleQueriable(witOracle), feedId);
    }

    function lastValidQueryResponse(bytes4 feedId)
        override public view
        returns (Witnet.QueryResponse memory)
    {
        return IWitOracleQueriable(witOracle).getQueryResponse(
            WitPriceFeedsLegacyDataLib.lastValidQueryId(IWitOracleQueriable(witOracle), feedId)
        );
    }

    function latestUpdateQueryId(bytes4 feedId)
        override public view
        returns (uint256)
    {
        return WitPriceFeedsLegacyDataLib.seekRecord(feedId).latestUpdateQueryId;
    }

    function latestUpdateQueryRequest(bytes4 feedId)
        override external view 
        returns (Witnet.QueryRequest memory)
    {
        return IWitOracleQueriable(witOracle).getQueryRequest(latestUpdateQueryId(feedId));
    }

    // function latestUpdateQueryResult(bytes4 feedId)
    //     override external view
    //     returns (Witnet.DataResult memory)
    // {
    //     return witOracle.getQueryResult(latestUpdateQueryId(feedId));
    // }

    // function latestUpdateQueryResultStatus(bytes4 feedId)
    //     override public view
    //     returns (Witnet.ResultStatus)
    // {
    //     return WitPriceFeedsLegacyDataLib.latestUpdateQueryResultStatus(witOracle, feedId);
    // }

    // function latestUpdateQueryResultStatusDescription(bytes4 feedId) 
    //     override external view
    //     returns (string memory)
    // {
    //     return witOracle.getQueryResultStatusDescription(
    //         latestUpdateQueryId(feedId)
    //     );
    // }

    function lookupWitnetBytecode(bytes4 feedId)
        override public view
        returns (bytes memory)
    {
        WitPriceFeedsLegacyDataLib.Record storage __record = WitPriceFeedsLegacyDataLib.seekRecord(feedId);
        _require(
            __record.radHash != 0,
            "no RAD hash"
        );
        return _registry().lookupRadonRequestBytecode(Witnet.RadonHash.wrap(__record.radHash));
    }

    function lookupWitnetRadHash(bytes4 feedId)
        override public view
        returns (bytes32)
    {
        return WitPriceFeedsLegacyDataLib.seekRecord(feedId).radHash;
    }

    function lookupWitnetRetrievals(bytes4 feedId)
        override external view
        returns (Witnet.RadonRetrieval[] memory _retrievals)
    {
        return _registry().lookupRadonRequestRetrievals(
            Witnet.RadonHash.wrap(lookupWitnetRadHash(feedId))
        );
    }

    function requestUpdate(bytes4 feedId)
        external payable
        virtual override
        returns (uint256)
    {
        return __requestUpdate(feedId, __defaultQuerySLA);
    }
    
    // function requestUpdate(bytes4 feedId, IWitPriceFeedsLegacy.RadonSLA calldata updateSLA)
    //     public payable
    //     virtual override
    //     returns (uint256)
    // {
    //     return __requestUpdate(
    //         feedId, 
    //         _intoQuerySLA(updateSLA)
    //     );
    // }
    

    /// ===============================================================================================================
    /// --- IWitFeedsLegacy -------------------------------------------------------------------------------------------
    
    function defaultRadonSLA() override external view returns (IWitPriceFeedsLegacy.RadonSLA memory) {
        return IWitPriceFeedsLegacy.RadonSLA({
            numWitnesses: uint8(__defaultQuerySLA.witCommitteeSize),
            unitaryReward: __defaultQuerySLA.witInclusionFees
        });
    }

    function latestUpdateResponse(bytes4 feedId) 
        override external view 
        returns (Witnet.QueryResponse memory)
    {
        return IWitOracleQueriable(witOracle).getQueryResponse(latestUpdateQueryId(feedId));
    }

    function latestUpdateResponseStatus(bytes4 feedId)
        override public view
        returns (IWitOracleLegacy.QueryResponseStatus)
    {
        return IWitOracleLegacy(witOracle).getQueryResponseStatus(latestUpdateQueryId(feedId));
    }

    function latestUpdateResultError(bytes4 feedId)
        override external view 
        returns (IWitOracleLegacy.ResultError memory)
    {
        return IWitOracleLegacy(witOracle).getQueryResultError(latestUpdateQueryId(feedId));
    }

    // function lookupWitnetBytecode(bytes4 feedId) 
    //     override external view
    //     returns (bytes memory)
    // {
    //     return lookupWitnetBytecode(feedId);
    // }
    
    function requestUpdate(bytes4 feedId, IWitPriceFeedsLegacy.RadonSLAv2 calldata legacySLA)
        external payable
        virtual override
        returns (uint256)
    {
        return __requestUpdate(feedId, _intoQuerySLA(legacySLA));
    }

    function witnet() virtual override external view returns (address) {
        return address(witOracle);
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeedsLegacyAdmin' -----------------------------------------------------------------------------

    function owner()
        virtual override (IWitPriceFeedsLegacyAdmin, Ownable)
        public view 
        returns (address)
    {
        return Ownable.owner();
    }
    
    function acceptOwnership()
        virtual override (IWitPriceFeedsLegacyAdmin, Ownable2Step)
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
        virtual override (IWitPriceFeedsLegacyAdmin, Ownable2Step)
        public view
        returns (address)
    {
        return Ownable2Step.pendingOwner();
    }
    
    function transferOwnership(address _newOwner)
        virtual override (IWitPriceFeedsLegacyAdmin, Ownable2Step)
        public 
        onlyOwner
    {
        Ownable.transferOwnership(_newOwner);
    }

    function deleteFeed(string calldata caption) virtual override external onlyOwner {
        try WitPriceFeedsLegacyDataLib.deleteFeed(caption) {
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertWitPriceFeedsLegacyDataLibUnhandledException();
        }
    }

    function deleteFeeds() virtual override external onlyOwner {
        try WitPriceFeedsLegacyDataLib.deleteFeeds() {
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertWitPriceFeedsLegacyDataLibUnhandledException();
        }
    }

    function settleBaseFeeOverheadPercentage(uint16 _baseFeeOverheadPercentage)
        virtual override
        external
        onlyOwner 
    {
        __baseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    function settleDefaultUpdateSLA(uint16 _numWitnesses, uint64 _unitaryReward)
        override public
        onlyOwner
    {
        __defaultQuerySLA.witCommitteeSize = _numWitnesses;
        __defaultQuerySLA.witUnitaryReward = _unitaryReward;
        _require(
            __defaultQuerySLA.isValid(), 
            "invalid update SLA"
        );
    }
    
    function settleFeedRequest(string calldata caption, bytes32 radHash)
        override public
        onlyOwner
    {
        _require(
            _registry().lookupRadonRequestResultDataType(Witnet.RadonHash.wrap(radHash)) == dataType,
            "bad result data type"
        );
        try WitPriceFeedsLegacyDataLib.settleFeedRequest(caption, radHash) {

        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitPriceFeedsLegacyDataLibUnhandledException();
        }
    }

    function settleFeedRequest(string calldata caption, IWitOracleRequest request)
        override external
        onlyOwner
    {
        settleFeedRequest(caption, Witnet.RadonHash.unwrap(request.radHash()));
    }

    function settleFeedRequest(
            string calldata caption,
            IWitOracleRequestTemplate template,
            string[][] calldata args
        )
        override external
        onlyOwner
    {
        settleFeedRequest(caption, Witnet.RadonHash.unwrap(template.verifyRadonRequest(args)));
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
        try WitPriceFeedsLegacyDataLib.settleFeedSolver(caption, solver, deps) {
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitPriceFeedsLegacyDataLibUnhandledException();
        }
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeeds' -----------------------------------------------------------------------------

    function lookupDecimals(bytes4 feedId) 
        override 
        external view
        returns (uint8)
    {
        return WitPriceFeedsLegacyDataLib.seekRecord(feedId).decimals;
    }
    
    function lookupPriceSolver(bytes4 feedId)
        override
        external view
        returns (address _solverAddress, string[] memory _solverDeps)
    {
        return WitPriceFeedsLegacyDataLib.seekPriceSolver(feedId);
    }

    function latestPrice(bytes4 feedId)
        virtual override
        public view
        returns (IWitPriceFeedsLegacySolver.Price memory)
    {
        try WitPriceFeedsLegacyDataLib.latestPrice(
            IWitOracleQueriable(witOracle), 
            feedId
        ) returns (IWitPriceFeedsLegacySolver.Price memory _latestPrice) {
            return _latestPrice;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitPriceFeedsLegacyDataLibUnhandledException();
        }
    }

    function latestPrices(bytes4[] calldata feedIds)
        virtual override
        external view
        returns (IWitPriceFeedsLegacySolver.Price[] memory _prices)
    {
        _prices = new IWitPriceFeedsLegacySolver.Price[](feedIds.length);
        for (uint _ix = 0; _ix < feedIds.length; _ix ++) {
            _prices[_ix] = latestPrice(feedIds[_ix]);
        }
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeedsLegacySolverFactory' ---------------------------------------------------------------------

    function deployPriceSolver(bytes calldata initcode, bytes calldata constructorParams)
        virtual override external
        onlyOwner
        returns (address)
    {
        try WitPriceFeedsLegacyDataLib.deployPriceSolver(
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
            _revertWitPriceFeedsLegacyDataLibUnhandledException();
        }
    }

    function determinePriceSolverAddress(bytes calldata initcode, bytes calldata constructorParams)
        virtual override public view
        returns (address _address)
    {
        return WitPriceFeedsLegacyDataLib.determinePriceSolverAddress(initcode, constructorParams);
    }


    // ================================================================================================================
    // --- Implements 'IERC2362' --------------------------------------------------------------------------------------
    
    function valueFor(bytes32 feedId)
        virtual override
        external view
        returns (int256 _value, uint256 _timestamp, uint256 _status)
    {
        IWitPriceFeedsLegacySolver.Price memory _latestPrice = latestPrice(bytes4(feedId));
        return (
            int(uint(_latestPrice.value)),
            Witnet.Timestamp.unwrap(_latestPrice.timestamp),
            (_latestPrice.latestStatus == IWitPriceFeedsLegacySolver.LatestUpdateStatus.Ready
                ? 200
                : (_latestPrice.latestStatus == IWitPriceFeedsLegacySolver.LatestUpdateStatus.Awaiting
                    ? 404 
                    : 400
                )
            )
        );
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _footprintOf(bytes4 _id4) virtual internal view returns (bytes4) {
        if (WitPriceFeedsLegacyDataLib.seekRecord(_id4).radHash != bytes32(0)) {
            return bytes4(keccak256(abi.encode(_id4, WitPriceFeedsLegacyDataLib.seekRecord(_id4).radHash)));
        } else {
            return bytes4(keccak256(abi.encode(_id4, WitPriceFeedsLegacyDataLib.seekRecord(_id4).solverDepsFlag)));
        }
    }

    function _intoQuerySLA(IWitPriceFeedsLegacy.RadonSLAv2 memory _updateSLA) internal view returns (Witnet.QuerySLA memory) {
        if (
            _updateSLA.numWitnesses >= __defaultQuerySLA.witCommitteeSize
                && _updateSLA.unitaryReward >= __defaultQuerySLA.witUnitaryReward
        ) {
            return Witnet.QuerySLA({
                witCommitteeSize: _updateSLA.numWitnesses,
                witUnitaryReward: _updateSLA.unitaryReward,
                witResultMaxSize: __defaultQuerySLA.witResultMaxSize
            });
        
        } else {
            _revert("unsecure update request");
        }
    }

    function _validateCaption(string calldata caption)
        internal view returns (uint8)
    {
        _require(
            bytes6(bytes(caption)) == bytes6(__prefix),
            "bad caption prefix"
        );
        try WitPriceFeedsLegacyDataLib.validateCaption(caption) returns (uint8 _decimals) {
            return _decimals;
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertWitPriceFeedsLegacyDataLibUnhandledException();
        }
    }

    function _revertWitPriceFeedsLegacyDataLibUnhandledException() internal view {
        _revert(_revertWitPriceFeedsLegacyDataLibUnhandledExceptionReason());
    }

    function _revertWitPriceFeedsLegacyDataLibUnhandledExceptionReason() internal pure returns (string memory) {
        return string(abi.encodePacked(
            type(WitPriceFeedsLegacyDataLib).name,
            ": unhandled assertion"
        ));
    }

    function __requestUpdate(bytes4[] memory _deps, IWitPriceFeedsLegacy.RadonSLAv2 memory sla)
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
        if (WitPriceFeedsLegacyDataLib.seekRecord(feedId).radHash != 0) {
            uint256 _evmUpdateRequestFee = msg.value;
            try WitPriceFeedsLegacyDataLib.requestUpdate(
                IWitOracleQueriable(witOracle),
                feedId,
                querySLA,
                _evmUpdateRequestFee
            
            ) returns (
                uint256 _latestQueryId,
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
                _revertWitPriceFeedsLegacyDataLibUnhandledException();
            }
        
        } else if (WitPriceFeedsLegacyDataLib.seekRecord(feedId).solver != address(0)) {
            return __requestUpdate(
                WitPriceFeedsLegacyDataLib.depsOf(feedId),
                IWitPriceFeedsLegacy.RadonSLAv2({
                    numWitnesses: uint8(querySLA.witCommitteeSize),
                    unitaryReward: querySLA.witUnitaryReward
                })
            );

        } else {
            _revert("unknown feed");
        }
    }

    function __storage() internal pure returns (WitPriceFeedsLegacyDataLib.Storage storage) {
        return WitPriceFeedsLegacyDataLib.data();
    }
}
