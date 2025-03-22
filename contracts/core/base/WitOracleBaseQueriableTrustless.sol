// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBaseQueriable.sol";
import "../../data/WitOracleTrustlessDataLib.sol";
import "../../interfaces/IWitOracleTrustless.sol";
import "../../interfaces/IWitOracleTrustlessReporter.sol";
import "../../patterns/Escrowable.sol";

/// @title Queriable WitOracle "trustless" base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBaseQueriableTrustless
    is 
        Escrowable,
        WitOracleBaseQueriable,
        IWitOracleTrustless,
        IWitOracleTrustlessReporter
{
    using Witnet for Witnet.DataPullReport;
    using WitOracleTrustlessDataLib for Witnet.Query;

    /// @notice Number of blocks to await for either a dispute or a proven response to some query.
    uint256 immutable public QUERY_AWAITING_BLOCKS;

    /// @notice Amount in wei to be staked upon reporting or disputing some query.
    uint256 immutable public QUERY_REPORTING_STAKE;

    modifier checkQueryReward(uint256 _msgValue, uint256 _baseFee) virtual override {
        if (_msgValue < _baseFee) {
            __burn(msg.sender, _baseFee - _msgValue);
        
        } else if (_msgValue > _baseFee * 10) {
            _revert("too much reward");

        } _;   
    }

    constructor(
            uint256 _queryAwaitingBlocks,
            uint256 _queryReportingStake
        )
        Payable(address(0))
    {
        _require(_queryAwaitingBlocks < 64, "too many awaiting blocks");
        _require(_queryReportingStake > 0, "no reporting stake?");
        
        QUERY_AWAITING_BLOCKS = _queryAwaitingBlocks;
        QUERY_REPORTING_STAKE = _queryReportingStake;

        // store genesis beacon:
        WitOracleTrustlessDataLib.data().beacons[
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
        return WitOracleTrustlessDataLib.data().escrows[tenant].collateral;
    }

    function balanceOf(address tenant)
        public view
        virtual override
        returns (uint256)
    {
        return WitOracleTrustlessDataLib.data().escrows[tenant].balance;
    }

    function withdraw()
        external
        virtual override
        returns (uint256 _withdrawn)
    {
        _withdrawn = WitOracleTrustlessDataLib.withdraw(msg.sender);
        __safeTransferTo(
            payable(msg.sender), 
            _withdrawn
        );
    }

    function __burn(address from, uint256 value) 
        virtual override
        internal
    {
        WitOracleTrustlessDataLib.burn(from, value);
    }

    function __deposit(address from, uint256 value)
        virtual override
        internal
    {
        WitOracleTrustlessDataLib.deposit(from, value);
    }

    function __stake(address from, uint256 value)
        virtual override
        internal
    {
        WitOracleTrustlessDataLib.stake(from, value);
    }

    function __slash(address from, address to, uint256 value)
        virtual override
        internal
    {
        WitOracleTrustlessDataLib.slash(from, to, value);
    }

    function __unstake(address from, uint256 value)
        virtual override
        internal
    {
        WitOracleTrustlessDataLib.unstake(from, value);
    }


    // ================================================================================================================
    // --- Overrides IWitOracle (trustlessly) -------------------------------------------------------------------------

    function parseDataReport(Witnet.DataPushReport calldata _dataPushReport, bytes calldata _proof)
        virtual override 
        external view
        returns (Witnet.DataResult memory)
    {
        (Witnet.FastForward[] memory _rollup, bytes32[] memory _merkle) = abi.decode(
            _proof, 
            (Witnet.FastForward[], bytes32[])
        );
        try WitOracleTrustlessDataLib.parseDataPushReport(
            _dataPushReport,
            _rollup,
            _merkle
        
        ) returns (
            Witnet.DataResult memory _queryResult
        ) {
            return _queryResult;
        
        } catch Error(string memory _reason) {
            revert(_reason);
        
        } catch (bytes memory) {
            revert("unhandled assertion");
        }
    }

    function pushDataReport(Witnet.DataPushReport calldata _dataPushReport, bytes calldata _proof)
        virtual override external
        returns (Witnet.DataResult memory)
    {
        (Witnet.FastForward[] memory _rollup, bytes32[] memory _merkle) = abi.decode(
            _proof, 
            (Witnet.FastForward[], bytes32[])
        );
        try WitOracleTrustlessDataLib.rollupDataPushReport(
            _dataPushReport,
            _rollup,
            _merkle
        
        ) returns (
            Witnet.DataResult memory _queryResult
        ) {
            return _queryResult;
        
        } catch Error(string memory _reason) {
            revert(_reason);
        
        } catch (bytes memory) {
            revert("unhandled assertion");
        }
    }


    // ================================================================================================================
    // --- Overrides IWitOracleQueriable (truslessly) -----------------------------------------------------------------

    /// @notice Removes all query data from storage. Pays back reward on expired queries.
    /// @dev Fails if the query is not in a final status, or not called from the actual requester.
    function deleteQuery(Witnet.QueryId _queryId)
        virtual override external
        returns (Witnet.QueryEvmReward)
    {
        try WitOracleTrustlessDataLib.deleteQueryTrustlessly(
            _queryId,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE
        
        ) returns (
            Witnet.QueryEvmReward _queryReward
        ) {
            uint256 _evmPayback = Witnet.QueryEvmReward.unwrap(_queryReward);
            if (_evmPayback > 0) {
                // transfer unused reward to requester, only if the query expired:
                __safeTransferTo(
                    payable(msg.sender),
                    _evmPayback
                );
            }
            return _queryReward;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertUnhandledException();
        }
    }

    function getQueryStatus(Witnet.QueryId _queryId)
        virtual override
        public view
        returns (Witnet.QueryStatus)
    {
        return WitOracleDataLib
            .seekQuery(_queryId)
            .getQueryStatusTrustlessly(QUERY_AWAITING_BLOCKS);
    }

    
    // ================================================================================================================
    // --- IWitOracleTrustless -------------------------------------------------------------------------------------------

    function determineBeaconIndexFromTimestamp(Witnet.Timestamp timestamp)
        virtual override
        external pure
        returns (uint64)
    {
        return Witnet.determineBeaconIndexFromTimestamp(timestamp);
    }
    
    function determineEpochFromTimestamp(Witnet.Timestamp timestamp)
        virtual override
        external pure
        returns (Witnet.BlockNumber)
    {
        return Witnet.determineEpochFromTimestamp(timestamp);
    }

    function getBeaconByIndex(uint32 index)
        virtual override
        public view
        returns (Witnet.Beacon memory)
    {
        return WitOracleTrustlessDataLib.seekBeacon(index);
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
        return WitOracleTrustlessDataLib.getLastKnownBeacon();
    }

    function getLastKnownBeaconIndex()
        virtual override
        public view
        returns (uint32)
    {
        return uint32(WitOracleTrustlessDataLib.getLastKnownBeaconIndex());
    }

    function rollupBeacons(Witnet.FastForward[] calldata _witOracleRollup)
        virtual override public 
        returns (Witnet.Beacon memory)
    {
        try WitOracleTrustlessDataLib.rollupBeacons(
            _witOracleRollup
        ) returns (
            Witnet.Beacon memory _witOracleHead
        ) {
            return _witOracleHead;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertUnhandledException();
        }
    }


    // ================================================================================================================
    // --- IWitOracleTrustlessReporter --------------------------------------------------------------------------------

    function claimQueryReward(Witnet.QueryId _queryId)
        virtual override external
        returns (uint256)
    {
        try WitOracleTrustlessDataLib.claimQueryReward(
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
            _revertUnhandledException();
        }
    }

    function claimQueryRewardBatch(Witnet.QueryId[] calldata _queryIds)
        virtual override external
        returns (uint256 _evmTotalReward)
    {
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            try WitOracleTrustlessDataLib.claimQueryReward(
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
                    _revertUnhandledExceptionReason()
                );
            }
        }
    }

    function disputeQueryResponse(Witnet.QueryId _queryId) 
        virtual override external
        returns (uint256)
    {
        try WitOracleTrustlessDataLib.disputeQueryResponse(
            _queryId,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE
        ) returns (uint256 _evmPotentialReward) {
            return _evmPotentialReward;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertUnhandledException();
        }
    }

    function reportQueryResponse(Witnet.DataPullReport calldata _responseReport)
        virtual override public 
        returns (uint256)
    {
        try WitOracleTrustlessDataLib.reportQueryResponseTrustlessly(
            _responseReport,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE

        ) returns (
            address evmReporter,
            uint256 evmGasPrice,
            uint64  evmFinalityBlock,
            Witnet.QueryId queryId,
            Witnet.Timestamp witDrResultTimestamp,
            Witnet.TransactionHash witDrTxHash,
            bytes memory witDrResultCborBytes
        ) {
            try WitOracleDataLib
                .reportResult(
                    evmReporter,
                    evmGasPrice,
                    evmFinalityBlock,
                    queryId,
                    witDrResultTimestamp,
                    witDrTxHash,
                    witDrResultCborBytes
            ) returns (
                uint256 _evmReward
            ) {
                return _evmReward;
            
            } catch Error(string memory _reason) {
                _revert(_reason);
            
            } catch (bytes memory) {
                _revertUnhandledException();    
            }
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertUnhandledException();
        }
    }
    
    function reportQueryResponseBatch(Witnet.DataPullReport[] calldata _responseReports)
        virtual override external 
        returns (uint256 _evmTotalReward)
    {
        for (uint _ix = 0; _ix < _responseReports.length; _ix ++) {
            Witnet.DataPullReport calldata _responseReport = _responseReports[_ix];
            try WitOracleTrustlessDataLib.reportQueryResponseTrustlessly(
                _responseReport,
                QUERY_AWAITING_BLOCKS,
                QUERY_REPORTING_STAKE
            ) returns (
                address evmReporter,
                uint256 evmGasPrice,
                uint64  evmFinalityBlock,
                Witnet.QueryId queryId,
                Witnet.Timestamp witDrResultTimestamp,
                Witnet.TransactionHash witDrTxHash,
                bytes memory witDrResultCborBytes
            ) {
                try WitOracleDataLib.reportResult(
                    evmReporter,
                    evmGasPrice,
                    evmFinalityBlock,
                    queryId,
                    witDrResultTimestamp,
                    witDrTxHash,
                    witDrResultCborBytes
                ) returns (
                    uint256 _evmPartialReward
                ) {
                    _evmTotalReward += _evmPartialReward;
                
                } catch Error(string memory _reason) {
                    emit BatchQueryError(
                        _responseReport.queryId,
                        _reason
                    );
                
                } catch (bytes memory) {
                    emit BatchQueryError(
                        _responseReport.queryId,
                        _revertUnhandledExceptionReason()
                    );
                }
            
            } catch Error(string memory _reason) {
                emit BatchQueryError(
                    _responseReport.queryId,
                    _reason
                );
    
            } catch (bytes memory) {
                emit BatchQueryError(
                    _responseReport.queryId,
                    _revertUnhandledExceptionReason()
                );
            }
        }
    }

    function rollupQueryResponseProof(
            Witnet.FastForward[] calldata _witOracleRollup, 
            Witnet.DataPullReport calldata _responseReport,
            bytes32[] calldata _queryResponseReportMerkleProof
        ) 
        virtual override external
        returns (uint256)
    {
        try WitOracleTrustlessDataLib.rollupQueryResponseProof(
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
            _revertUnhandledException();
        }
    }
}
