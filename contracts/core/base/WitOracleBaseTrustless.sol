// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBase.sol";
import "../../interfaces/IWitOracleBlocks.sol";
import "../../interfaces/IWitOracleTrustless.sol";
import "../../interfaces/IWitOracleTrustlessReporter.sol";
import "../../patterns/Escrowable.sol";

/// @title Witnet Request Board "trustless" implementation contract for regular EVM-compatible chains.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleBaseTrustless
    is 
        Escrowable,
        WitOracleBase,
        IWitOracleBlocks,
        IWitOracleTrustless,
        IWitOracleTrustlessReporter
{
    using Witnet for Witnet.DataPullReport;

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
        WitOracleDataLib.data().beacons[
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
        return WitOracleDataLib.data().escrows[tenant].collateral;
    }

    function balanceOf(address tenant)
        public view
        virtual override
        returns (uint256)
    {
        return WitOracleDataLib.data().escrows[tenant].balance;
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
    // --- Overrides IWitOracle (trustlessly) -------------------------------------------------------------------------

    /// @notice Removes all query data from storage. Pays back reward on expired queries.
    /// @dev Fails if the query is not in a final status, or not called from the actual requester.
    function deleteQuery(Witnet.QueryId _queryId)
        virtual override external
        returns (Witnet.QueryReward)
    {
        try WitOracleDataLib.deleteQueryTrustlessly(
            _queryId,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE
        
        ) returns (
            Witnet.QueryReward _queryReward
        ) {
            uint256 _evmPayback = Witnet.QueryReward.unwrap(_queryReward);
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
            _revertWitOracleDataLibUnhandledException();
        }
    }

    function getQueryStatus(Witnet.QueryId _queryId)
        virtual override
        public view
        returns (Witnet.QueryStatus)
    {
        return WitOracleDataLib.getQueryStatusTrustlessly(_queryId, QUERY_AWAITING_BLOCKS);
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
    // --- Overrides IWitOracle (trustlessly) -------------------------------------------------------------------------

    /// @notice Verify the data report was actually produced by the Wit/Oracle sidechain,
    /// @notice reverting if the verification fails, or returning the self-contained Witnet.Result value.
    function pushData(
                Witnet.DataPushReport calldata _report, 
                Witnet.FastForward[] calldata _rollup, 
                bytes32[] calldata _droMerkleTrie
            ) 
            external returns (Witnet.DataResult memory)
    {
        try WitOracleDataLib.rollupDataPushReport(
            _report,
            _rollup,
            _droMerkleTrie
        
        ) returns (
            Witnet.DataResult memory _queryResult
        ) {
            return _queryResult;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }


    // ================================================================================================================
    // --- IWitOracleTrustlessReporter --------------------------------------------------------------------------------

    function claimQueryReward(Witnet.QueryId _queryId)
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

    function claimQueryRewardBatch(Witnet.QueryId[] calldata _queryIds)
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

    function extractDataRequest(Witnet.QueryId _queryId)
        virtual override public view
        returns (DataRequest memory _dr)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatus(_queryId);
        if (
            _queryStatus == Witnet.QueryStatus.Posted
                || _queryStatus == Witnet.QueryStatus.Delayed
        ) {
            _dr = WitOracleDataLib.extractDataRequest(registry, _queryId);
        }
    }


    function extractDataRequestBatch(Witnet.QueryId[] calldata _queryIds)
        virtual override external view
        returns (DataRequest[] memory _drs)
    {
        _drs = new DataRequest[](_queryIds.length);
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            _drs[_ix] = extractDataRequest(_queryIds[_ix]);
        }
    }

    function disputeQueryResponse(Witnet.QueryId _queryId) 
        virtual override external
        returns (uint256)
    {
        try WitOracleDataLib.disputeQueryResponse(
            _queryId,
            QUERY_AWAITING_BLOCKS,
            QUERY_REPORTING_STAKE
        ) returns (uint256 _evmPotentialReward) {
            return _evmPotentialReward;
        
        } catch Error(string memory _reason) {
            _revert(_reason);
        
        } catch (bytes memory) {
            _revertWitOracleDataLibUnhandledException();
        }
    }

    function reportQueryResponse(Witnet.DataPullReport calldata _responseReport)
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
    
    function reportQueryResponseBatch(Witnet.DataPullReport[] calldata _responseReports)
        virtual override external 
        returns (uint256 _evmTotalReward)
    {
        for (uint _ix = 0; _ix < _responseReports.length; _ix ++) {
            Witnet.DataPullReport calldata _responseReport = _responseReports[_ix];
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
            Witnet.DataPullReport calldata _responseReport,
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
}
