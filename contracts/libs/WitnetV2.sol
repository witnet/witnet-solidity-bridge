    // SPDX-License-Identifier: MIT

    pragma solidity >=0.8.0 <0.9.0;

    import "./Witnet.sol";

    library WitnetV2 {

        uint256 constant _WITNET_INCEPTION_TS = 1602666000;

        struct Beacon {
            uint256 index;
            bytes32 root;       
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
            uint256 epoch;
            uint256 weiReward;
        address from;
        address reporter;
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
        bytes32 droHash;
        uint256 resultTimestamp;
        bytes   resultCborBytes;
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
        uint8 ratioEvmCollateral;
        uint8 ratioWitCollateral;
        uint64 witWitnessReward;
        uint64 witMinerFee;
    }

    function isValid(RadonSLAv2 calldata sla) internal pure returns (bool) {
        return (
            sla.committeeSize >= 1
                && sla.committeeConsensus >= 51
                && sla.committeeConsensus <= 99
                && sla.ratioEvmCollateral >= 1
                && sla.ratioWitCollateral >= 1
                && sla.ratioWitCollateral <= 127
                && sla.witWitnessReward >= 1
                && sla.witMinerFee >= 1
        );
    }

    function pack(RadonSLAv2 calldata sla) internal pure returns (bytes32) {
        return bytes32(abi.encodePacked(
            sla.committeeSize,
            sla.committeeConsensus,
            sla.ratioEvmCollateral,
            sla.ratioWitCollateral,
            sla.witWitnessReward,
            sla.witMinerFee
        ));
    }

    function toRadonSLAv2EvmCollateralRatio(bytes32 packed) internal pure returns (uint8) {
        return uint8(bytes1(packed << 16));
    }

    function toRadonSLAv2(bytes32 packed) internal pure returns (RadonSLAv2 memory sla) {
        return RadonSLAv2({
            committeeSize: uint8(bytes1(packed)),
            committeeConsensus: uint8(bytes1(packed << 8)),
            ratioEvmCollateral: uint8(bytes1(packed << 16)),
            ratioWitCollateral: uint8(bytes1(packed << 24)),
            witWitnessReward: uint64(bytes8(packed << 32)),
            witMinerFee: uint64(bytes8(packed << 96))
        });
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
                && a.ratioEvmCollateral >= b.ratioEvmCollateral
                && a.ratioWitCollateral >= b.ratioWitCollateral
                && a.witWitnessReward >= b.witWitnessReward
                && a.witMinerFee >= b.witMinerFee
        );
    }

    function blockNumberFromTimestamp(uint ts) internal pure returns (uint256) {
        return (ts - _WITNET_INCEPTION_TS) / 45;
    }

    function beaconIndexFromTimestamp(uint ts) internal pure returns (uint256) {
        return blockNumberFromTimestamp(ts) / 10;
    }

    function checkQueryPostStatus(uint queryEpoch, uint chainEpoch) internal pure returns (WitnetV2.QueryStatus) {
        if (chainEpoch >= queryEpoch + 3) {
            return WitnetV2.QueryStatus.Expired;
        } else if (chainEpoch >= queryEpoch + 2) {
            return WitnetV2.QueryStatus.Delayed;
        } else {
            return WitnetV2.QueryStatus.Posted;
        }
    }
}