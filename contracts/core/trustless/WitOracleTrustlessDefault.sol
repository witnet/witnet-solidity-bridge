// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleTrustlessBase.sol";

import "../../interfaces/IWitOracleBlocks.sol";
import "../../interfaces/IWitOracleReporterTrustless.sol";
import "../../patterns/Escrowable.sol";

/// @title Witnet Request Board "trustless" implementation contract for regular EVM-compatible chains.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustlessDefault
    is 
        Escrowable,
        WitOracleTrustlessBase,
        IWitOracleBlocks,
        IWitOracleReporterTrustless
{
    using Witnet for Witnet.QueryResponseReport;

    function class() virtual override public view  returns (string memory) {
        return type(WitOracleTrustlessDefault).name;
    }

    /// @notice Number of blocks to await for either a dispute or a proven response to some query.
    uint256 immutable public QUERY_AWAITING_BLOCKS;

    /// @notice Amount in wei to be staked upon reporting or disputing some query.
    uint256 immutable public QUERY_REPORTING_STAKE;

    modifier checkReward(uint256 _msgValue, uint256 _baseFee) virtual override {
        if (_msgValue < _baseFee) {
            __burn(msg.sender, _baseFee - _msgValue);
        
        } else if (_msgValue > _baseFee * 10) {
            _revert("too much reward");

        } _;   
    }

    constructor(
            WitOracleRadonRegistry _registry,
            WitOracleRequestFactory _factory,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas,
            uint256 _queryAwaitingBlocks,
            uint256 _queryReportingStake
        )
        Payable(address(0))
        WitOracleTrustlessBase(
            _registry,
            _factory
        )
    {
        __reportResultGasBase = _reportResultGasBase;
        __reportResultWithCallbackGasBase = _reportResultWithCallbackGasBase;
        __reportResultWithCallbackRevertGasBase = _reportResultWithCallbackRevertGasBase;
        __sstoreFromZeroGas = _sstoreFromZeroGas;

        _require(_queryAwaitingBlocks < 64, "too many awaiting blocks");
        _require(_queryReportingStake > 0, "no reporting stake?");
        
        QUERY_AWAITING_BLOCKS = _queryAwaitingBlocks;
        QUERY_REPORTING_STAKE = _queryReportingStake;

        // store genesis beacon:
        __storage().beacons[
            Witnet.WIT_2_GENESIS_BEACON_INDEX
        ] = Witnet.Beacon({
            index: Witnet.WIT_2_GENESIS_BEACON_INDEX,
            prevIndex: Witnet.WIT_2_GENESIS_BEACON_PREV_INDEX,
            prevRoot: Witnet.WIT_2_GENESIS_BEACON_PREV_ROOT,
            ddrTalliesMerkleRoot: Witnet.WIT_2_GENESIS_BEACON_DDR_TALLIES_MERKLE_ROOT,
            droTalliesMerkleRoot: Witnet.WIT_2_GENESIS_BEACON_DRO_TALLIES_MERKLE_ROOT,
            nextCommitteeAggPubkey: [
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_0,
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_1,
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_2,
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_3
            ]
        });
    }

    
    // ================================================================================================================
    // --- Escrowable -------------------------------------------------------------------------------------------------

    receive() external payable virtual override {
        __deposit(msg.sender, _getMsgValue());
    }

    function collateralOf(address tenant)
        public view
        virtual override
        returns (uint256)
    {
        return __storage().escrows[tenant].collateral;
    }

    function balanceOf(address tenant)
        public view
        virtual override
        returns (uint256)
    {
        return __storage().escrows[tenant].balance;
    }

    function withdraw()
        external
        virtual override
        returns (uint256 _withdrawn)
    {
        _withdrawn = WitOracleDataLib.withdraw(msg.sender);
        __safeTransferTo(
            payable(msg.sender), 
            _withdrawn
        );
    }

    function __burn(address from, uint256 value) 
        virtual override
        internal
    {
        WitOracleDataLib.burn(from, value);
    }

    function __deposit(address from, uint256 value)
        virtual override
        internal
    {
        WitOracleDataLib.deposit(from, value);
    }

    function __stake(address from, uint256 value)
        virtual override
        internal
    {
        WitOracleDataLib.stake(from, value);
    }

    function __slash(address from, address to, uint256 value)
        virtual override
        internal
    {
        WitOracleDataLib.slash(from, to, value);
    }

    function __unstake(address from, uint256 value)
        virtual override
        internal
    {
        WitOracleDataLib.unstake(from, value);
    }


    // ================================================================================================================
    // --- IWitOracle (trustlessly) -----------------------------------------------------------------------------------

    function fetchQueryResponse(uint256 _queryId)
        virtual override
        external
        onlyRequester(_queryId)
        returns (Witnet.QueryResponse memory)
    {
        try WitOracleDataLib.fetchQueryResponseTrustlessly(
            _queryId,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE
        
        ) returns (
            Witnet.QueryResponse memory _queryResponse
        ) {
            return _queryResponse;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }

    function getQueryStatus(uint256 _queryId)
        virtual override
        public view
        returns (Witnet.QueryStatus)
    {
        return WitOracleDataLib.getQueryStatusTrustlessly(_queryId, QUERY_AWAITING_BLOCKS);
    }

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query has been succesfully solved;
    /// @notice   - 3 => Error: the query couldn't get solved due to some issue.
    /// @param _queryId The unique query identifier.
    function getQueryResponseStatus(uint256 _queryId)
        virtual override
        public view
        returns (Witnet.QueryResponseStatus)
    {
        return WitOracleDataLib.getQueryResponseStatusTrustlessly(_queryId, QUERY_AWAITING_BLOCKS);
    }


    // ================================================================================================================
    // --- IWitOracleBlocks -------------------------------------------------------------------------------------------

    function determineBeaconIndexFromTimestamp(uint32 timestamp)
        virtual override
        external pure
        returns (uint32)
    {
        return Witnet.determineBeaconIndexFromTimestamp(timestamp);
    }
    
    function determineEpochFromTimestamp(uint32 timestamp)
        virtual override
        external pure
        returns (uint32)
    {
        return Witnet.determineEpochFromTimestamp(timestamp);
    }

    function getBeaconByIndex(uint32 index)
        virtual override
        public view
        returns (Witnet.Beacon memory)
    {
        return WitOracleDataLib.seekBeacon(index);
    }

    function getGenesisBeacon() 
        virtual override 
        external pure
        returns (Witnet.Beacon memory)
    {
        return Witnet.Beacon({
            index: Witnet.WIT_2_GENESIS_BEACON_INDEX,
            prevIndex: Witnet.WIT_2_GENESIS_BEACON_PREV_INDEX,
            prevRoot: Witnet.WIT_2_GENESIS_BEACON_PREV_ROOT,
            ddrTalliesMerkleRoot: Witnet.WIT_2_GENESIS_BEACON_DDR_TALLIES_MERKLE_ROOT,
            droTalliesMerkleRoot: Witnet.WIT_2_GENESIS_BEACON_DRO_TALLIES_MERKLE_ROOT,
            nextCommitteeAggPubkey: [
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_0,
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_1,
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_2,
                Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_3
            ]
        });
    }

    function getLastKnownBeacon() 
        virtual override
        public view
        returns (Witnet.Beacon memory)
    {
        return WitOracleDataLib.getLastKnownBeacon();
    }

    function getLastKnownBeaconIndex()
        virtual override
        public view
        returns (uint32)
    {
        return uint32(WitOracleDataLib.getLastKnownBeaconIndex());
    }

    function rollupBeacons(Witnet.FastForward[] calldata _witOracleRollup)
        virtual override public 
        returns (Witnet.Beacon memory)
    {
        try WitOracleDataLib.rollupBeacons(
            _witOracleRollup
        ) returns (
            Witnet.Beacon memory _witOracleHead
        ) {
            return _witOracleHead;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }


    // ================================================================================================================
    // --- IWitOracleReporterTrustless --------------------------------------------------------------------------------

    function claimQueryReward(uint256 _queryId)
        virtual override external
        returns (uint256)
    {
        try WitOracleDataLib.claimQueryReward(
            _queryId, 
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE

        ) returns (
            uint256 _evmReward
        ) {
            return _evmReward;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }

    function claimQueryRewardBatch(uint256[] calldata _queryIds)
        virtual override external
        returns (uint256 _evmTotalReward)
    {
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            try WitOracleDataLib.claimQueryReward(
                _queryIds[_ix],
                QUERY_AWAITING_BLOCKS,
                QUERY_REPORTING_STAKE
                
            ) returns (uint256 _evmReward) {
                _evmTotalReward += _evmReward;
            
            } catch Error(string memory _reason) {
                emit BatchQueryError(
                    _queryIds[_ix], 
                    _reason
                );
        
            } catch (bytes memory) {
                emit BatchQueryError(
                    _queryIds[_ix], 
                    _revertWitOracleDataLibUnhandledExceptionReason()
                );
            }
        }
    }

    function extractQueryRelayData(uint256 _queryId)
        virtual override public view
        returns (QueryRelayData memory _queryRelayData)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatus(_queryId);
        if (
            _queryStatus == Witnet.QueryStatus.Posted
                || _queryStatus == Witnet.QueryStatus.Delayed
        ) {
            _queryRelayData = WitOracleDataLib.extractQueryRelayData(registry, _queryId);
        }
    }

    function extractQueryRelayDataBatch(uint256[] calldata _queryIds)
        virtual override external view
        returns (QueryRelayData[] memory _relays)
    {
        _relays = new QueryRelayData[](_queryIds.length);
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            _relays[_ix] = extractQueryRelayData(_queryIds[_ix]);
        }
    }

    function disputeQueryResponse(uint256 _queryId) 
        virtual override external
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (uint256)
    {
        return WitOracleDataLib.disputeQueryResponse(
            _queryId,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE
        );
    }

    function reportQueryResponse(Witnet.QueryResponseReport calldata _responseReport)
        virtual override public 
        returns (uint256)
    {
        try WitOracleDataLib.reportQueryResponseTrustlessly(
                _responseReport,
                QUERY_AWAITING_BLOCKS,
                QUERY_REPORTING_STAKE
        
        ) returns (uint256 _evmReward) {
            return _evmReward;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }
    
    function reportQueryResponseBatch(Witnet.QueryResponseReport[] calldata _responseReports)
        virtual override external 
        returns (uint256 _evmTotalReward)
    {
        for (uint _ix = 0; _ix < _responseReports.length; _ix ++) {
            Witnet.QueryResponseReport calldata _responseReport = _responseReports[_ix];
            try WitOracleDataLib.reportQueryResponseTrustlessly(
                _responseReport,
                QUERY_AWAITING_BLOCKS,
                QUERY_REPORTING_STAKE
            
            ) returns (uint256 _evmPartialReward) {
                _evmTotalReward += _evmPartialReward;
            
            } catch Error(string memory _reason) {
                emit BatchQueryError(
                    _responseReport.queryId,
                    _reason
                );
    
            } catch (bytes memory) {
                emit BatchQueryError(
                    _responseReport.queryId,
                    _revertWitOracleDataLibUnhandledExceptionReason()
                );
            }
        }
    }

    function rollupQueryResponseProof(
            Witnet.FastForward[] calldata _witOracleRollup, 
            Witnet.QueryResponseReport calldata _responseReport,
            bytes32[] calldata _queryResponseReportMerkleProof
        ) 
        virtual override external
        returns (uint256)
    {
        try WitOracleDataLib.rollupQueryResponseProof(
            _witOracleRollup,
            _responseReport,
            _queryResponseReportMerkleProof,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE
            
        ) returns (
            uint256 _evmReward
        ) {
            return _evmReward;
        }
        catch Error(string memory _reason) {
            _revert(_reason);
        }
        catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }

    function rollupQueryResultProof(
            Witnet.FastForward[] calldata _witOracleRollup,
            Witnet.QueryReport calldata _queryReport,
            bytes32[] calldata _queryReportMerkleProof
        )
        virtual override external
        returns (Witnet.Result memory)
    {
        try WitOracleDataLib.rollupQueryResultProof(
            _witOracleRollup,
            _queryReport,
            _queryReportMerkleProof
        
        ) returns (
            Witnet.Result memory _queryResult
        ) {
            return _queryResult;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }
}
