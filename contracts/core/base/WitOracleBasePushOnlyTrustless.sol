// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBasePushOnly.sol";

import "../../data/WitOracleTrustlessDataLib.sol";
import "../../data/WitOracleDataLib.sol";

/// @title Push-only WitOracle "trustless" base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBasePushOnlyTrustless
    is 
        WitOracleBasePushOnly,
        IWitOracleTrustless
{
    using Witnet for Witnet.DataPushReport;

    constructor() {
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
    // --- IWitOracle -------------------------------------------------------------------------------------------------

    function parseDataReport(Witnet.DataPushReport calldata _report, bytes calldata _signature)
        virtual override public view
        returns (Witnet.DataResult memory _result)
    {
        (, _result) = WitOracleDataLib.parseDataReport(_report, _signature);
    }

    function pushDataReport(Witnet.DataPushReport calldata _report, bytes calldata _signature)
        virtual override external
        returns (Witnet.DataResult memory)
    {
        (address _evmSigner, Witnet.DataResult memory _result) = WitOracleDataLib.parseDataReport(_report, _signature);
        emit WitOracleReport(
            tx.origin, 
            msg.sender, 
            _evmSigner, 
            _report.witDrTxHash,
            _report.queryRadHash,
            _report.queryParams,
            _report.resultTimestamp,
            _report.resultCborBytes,
            _result.status
        );
        return _result;
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
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _revertUnhandledExceptionReason() 
        virtual override internal pure returns (string memory)
    {
        return string(abi.encodePacked(
            type(WitOracleTrustlessDataLib).name,
            ": unhandled assertion"
        ));
    }

    // /// Returns storage pointer to contents of 'WitOracleDataLib.Storage' struct.
    // function __storage() virtual internal pure returns (WitOracleDataLib.Storage storage _ptr) {
    //   return WitOracleDataLib.data();
    // }
}
