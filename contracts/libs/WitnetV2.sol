// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./Witnet.sol";

library WitnetV2 {

    uint256 constant _WITNET_BLOCK_TIME_SECS = 45;
    uint256 constant _WITNET_INCEPTION_TS = 1602666000;
    uint256 constant _WITNET_SUPERBLOCK_EPOCHS = 10;

    struct Beacon {
        uint256 index;
        uint256 prevIndex;
        bytes32 prevRoot;
        bytes32 nextBlsRoot;
        bytes32 ddrTallyRoot;
    }

    struct FastForward {
        Beacon next;
        bytes32[] signatures;
    }
    
    /// Possible status of a WitnetV2 query.
    enum QueryStatus {
        Void,
        Posted,
        Reported,
        Delayed,
        Disputed,
        Expired,
        Finalized
    }

    struct Query {
        address from;
        address reporter;
        uint256 postEpoch;
        uint256 reportEpoch;
        uint256 weiReward;
        uint256 weiStake;
        QueryRequest request;
        QueryReport report;
        QueryCallback callback;
        QueryDispute[] disputes;
    }

    struct QueryDispute {
        address disputer;
        QueryReport report;
    }

    struct QueryCallback {
        address addr;
        uint256 gas;
    }

    struct QueryRequest {
        bytes32 radHash;
        bytes32 packedSLA;
    }

    struct QueryReport {
        address relayer;
        uint256 tallyEpoch;
        bytes   tallyCborBytes;
    }

    struct DataProvider {
        string  authority;
        uint256 totalEndpoints;
        mapping (uint256 => bytes32) endpoints;
    }

    enum DataRequestMethods {
        /* 0 */ Unknown,
        /* 1 */ HttpGet,
        /* 2 */ Rng,
        /* 3 */ HttpPost
    }

    enum RadonDataTypes {
        /* 0x00 */ Any, 
        /* 0x01 */ Array,
        /* 0x02 */ Bool,
        /* 0x03 */ Bytes,
        /* 0x04 */ Integer,
        /* 0x05 */ Float,
        /* 0x06 */ Map,
        /* 0x07 */ String,
        Unused0x08, Unused0x09, Unused0x0A, Unused0x0B,
        Unused0x0C, Unused0x0D, Unused0x0E, Unused0x0F,
        /* 0x10 */ Same,
        /* 0x11 */ Inner,
        /* 0x12 */ Match,
        /* 0x13 */ Subscript
    }

    struct RadonFilter {
        RadonFilterOpcodes opcode;
        bytes args;
    }

    enum RadonFilterOpcodes {
        /* 0x00 */ GreaterThan,
        /* 0x01 */ LessThan,
        /* 0x02 */ Equals,
        /* 0x03 */ AbsoluteDeviation,
        /* 0x04 */ RelativeDeviation,
        /* 0x05 */ StandardDeviation,
        /* 0x06 */ Top,
        /* 0x07 */ Bottom,
        /* 0x08 */ Mode,
        /* 0x09 */ LessOrEqualThan
    }

    struct RadonReducer {
        RadonReducerOpcodes opcode;
        RadonFilter[] filters;
        bytes script;
    }

    enum RadonReducerOpcodes {
        /* 0x00 */ Minimum,
        /* 0x01 */ Maximum,
        /* 0x02 */ Mode,
        /* 0x03 */ AverageMean,
        /* 0x04 */ AverageMeanWeighted,
        /* 0x05 */ AverageMedian,
        /* 0x06 */ AverageMedianWeighted,
        /* 0x07 */ StandardDeviation,
        /* 0x08 */ AverageDeviation,
        /* 0x09 */ MedianDeviation,
        /* 0x0A */ MaximumDeviation,
        /* 0x0B */ ConcatenateAndHash
    }

    struct RadonRetrieval {
        uint8 argsCount;
        DataRequestMethods method;
        RadonDataTypes resultDataType;
        string url;
        string body;
        string[2][] headers;
        bytes script;
    }

    struct RadonSLA {
        uint numWitnesses;
        uint minConsensusPercentage;
        uint witnessReward;
        uint witnessCollateral;
        uint minerCommitRevealFee;
        uint minMinerFee;
    }

    struct RadonSLAv2 {
        uint8 committeeSize;
        uint8 committeeConsensus;
        uint8 ratioWitCollateral;
        uint8 reserved;
        uint64 witWitnessReward;
        uint64 witMinMinerFee;
    }

    function beaconIndexFromEpoch(uint epoch) internal pure returns (uint256) {
        return epoch / 10;
    }

    function beaconIndexFromTimestamp(uint ts) internal pure returns (uint256) {
        return 1 + epochFromTimestamp(ts) / _WITNET_SUPERBLOCK_EPOCHS;
    }

    function checkQueryPostStatus(
            uint queryPostEpoch, 
            uint currentEpoch
        ) 
        internal pure 
        returns (WitnetV2.QueryStatus)
    {
        if (currentEpoch > queryPostEpoch + _WITNET_SUPERBLOCK_EPOCHS) {
            if (currentEpoch > queryPostEpoch + _WITNET_SUPERBLOCK_EPOCHS * 2) {
                return WitnetV2.QueryStatus.Expired;
            } else {
                return WitnetV2.QueryStatus.Delayed;
            }
        } else {
            return WitnetV2.QueryStatus.Posted;
        }
    }

    function checkQueryReportStatus(
            uint queryReportEpoch,
            uint currentEpoch
        )
        internal pure
        returns (WitnetV2.QueryStatus)
    {
        if (currentEpoch > queryReportEpoch + _WITNET_SUPERBLOCK_EPOCHS) {
            return WitnetV2.QueryStatus.Finalized;
        } else {
            return WitnetV2.QueryStatus.Reported;
        }
    }

    /// @notice Returns `true` if all witnessing parameters in `b` have same
    /// @notice value or greater than the ones in `a`.
    function equalOrGreaterThan(RadonSLA memory a, RadonSLA memory b)
        internal pure
        returns (bool)
    {
        return (
            a.numWitnesses >= b.numWitnesses
                && a.minConsensusPercentage >= b.minConsensusPercentage
                && a.witnessReward >= b.witnessReward
                && a.witnessCollateral >= b.witnessCollateral
                && a.minerCommitRevealFee >= b.minerCommitRevealFee
                && a.minMinerFee >= b.minMinerFee
        );
    }

    /// @notice Returns `true` if all witnessing parameters in `b` have same
    /// @notice value or greater than the ones in `a`.
    function equalOrGreaterThan(RadonSLAv2 memory a, RadonSLAv2 memory b)
        internal pure
        returns (bool)
    {
        return (
            a.committeeSize >= b.committeeSize
                && a.committeeConsensus >= b.committeeConsensus
                // && a.ratioEvmCollateral >= b.ratioEvmCollateral
                && a.ratioWitCollateral >= b.ratioWitCollateral
                && a.witWitnessReward >= b.witWitnessReward
                && a.witMinMinerFee >= b.witMinMinerFee
        );
    }

    function epochFromTimestamp(uint ts) internal pure returns (uint256) {
        return (ts - _WITNET_INCEPTION_TS) / _WITNET_BLOCK_TIME_SECS;
    }

    function isValid(RadonSLAv2 calldata sla) internal pure returns (bool) {
        return (
            sla.committeeSize >= 1
                && sla.committeeConsensus >= 51
                && sla.committeeConsensus <= 99
                && sla.ratioWitCollateral >= 1
                && sla.ratioWitCollateral <= 127
                && sla.witWitnessReward >= 1
                && sla.witMinMinerFee >= 1
        );
    }

    function pack(RadonSLAv2 calldata sla) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(
            sla.committeeSize,
            sla.committeeConsensus,
            sla.ratioWitCollateral,
            uint8(0),
            sla.witWitnessReward,
            sla.witMinMinerFee
        ));
    }

    function tallyHash(QueryReport calldata self, bytes32 queryHash)
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(
            queryHash,
            self.relayer,
            self.tallyEpoch,
            self.tallyCborBytes
        ));
    }

    function tallyHash(QueryReport storage self, bytes32 queryHash)
        internal view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(
            queryHash,
            self.relayer,
            self.tallyEpoch,
            self.tallyCborBytes
        ));
    }

    function toRadonSLAv2(bytes32 packed) internal pure returns (RadonSLAv2 memory sla) {
        return RadonSLAv2({
            committeeSize: uint8(bytes1(packed)),
            committeeConsensus: uint8(bytes1(packed << 8)),
            ratioWitCollateral: uint8(bytes1(packed << 16)),
            reserved: 0,
            witWitnessReward: uint64(bytes8(packed << 32)),
            witMinMinerFee: uint64(bytes8(packed << 96))
        });
    }

    function merkle(bytes32[] calldata items) internal pure returns (bytes32) {
        // TODO
    }

    function merkle(WitnetV2.Beacon memory self) internal pure returns (bytes32) {
        // TODO
    }

    function verifyFastForward(WitnetV2.Beacon memory self, WitnetV2.FastForward calldata ff)
        internal pure
        returns (WitnetV2.Beacon memory)
    {
        require(
            self.index == ff.next.prevIndex
                && merkle(self) == ff.next.prevRoot,
            "WitnetV2: misplaced fastforward"
        );
        // TODO verify ff proofs
        return ff.next;
    }
   
}