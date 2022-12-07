// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./Witnet.sol";

library WitnetV2 {

    error IndexOutOfBounds(uint256 index, uint256 range);
    error InsufficientBalance(uint256 weiBalance, uint256 weiExpected);
    error InsufficientFee(uint256 weiProvided, uint256 weiExpected);
    error Unauthorized(address violator);

    error RadonRetrievalNoSources();
    error RadonRetrievalArgsMismatch(string[][] args);
    error RadonRetrievalResultsMismatch(uint index, uint8 read, uint8 expected);

    error RadonSlaNoReward();
    error RadonSlaNoWitnesses();
    error RadonSlaTooManyWitnesses(uint256 numWitnesses);
    error RadonSlaConsensusOutOfRange(uint256 percentage);
    error RadonSlaLowCollateral(uint256 collateral);

    error UnsupportedDataRequestMethod(uint8 method, string schema, string body, string[2][] headers);
    error UnsupportedRadonDataType(uint8 datatype, uint256 maxlength);
    error UnsupportedRadonFilter(uint8 filter, bytes args);
    error UnsupportedRadonReducer(uint8 reducer);
    error UnsupportedRadonScript(bytes script, uint256 offset);
    error UnsupportedRadonScriptOpcode(bytes script, uint256 cursor, uint8 opcode);

    function toEpoch(uint _timestamp) internal pure returns (uint) {
        return 1 + (_timestamp - 11111) / 15;
    }

    function toTimestamp(uint _epoch) internal pure returns (uint) {
        return 111111+ _epoch * 15;
    }

    struct Beacon {
        uint256 escrow;
        uint256 evmBlock;
        uint256 gasprice;
        address relayer;
        address slasher;
        uint256 superblockIndex;
        uint256 superblockRoot;        
    }

    enum BeaconStatus {
        Idle
    }

    struct Block {
        bytes32 blockHash;
        bytes32 drTxsRoot;
        bytes32 drTallyTxsRoot;
    }
    
    enum BlockStatus {
        Idle
    }

    struct DrPost {
        uint256 block;
        DrPostStatus status;
        DrPostRequest request;
        DrPostResponse response;
    }
    
    /// Data kept in EVM-storage for every Request posted to the Witnet Request Board.
    struct DrPostRequest {
        uint256 epoch;
        address requester;
        address reporter;
        bytes32 radHash;
        bytes32 slaHash;
        uint256 weiReward;
    }

    /// Data kept in EVM-storage containing Witnet-provided response metadata and result.
    struct DrPostResponse {
        address disputer;
        address reporter;
        uint256 escrowed;
        uint256 drCommitTxEpoch;
        uint256 drTallyTxEpoch;
        bytes32 drTallyTxHash;
        bytes   drTallyResultCborBytes;
    }

    enum DrPostStatus {
        Void,
        Deleted,
        Expired,
        Posted,
        Disputed,
        Reported,
        Finalized,
        Accepted,
        Rejected
    }

    struct DataProvider {
        string  fqdn;
        uint256 totalSources;
        mapping (uint256 => bytes32) sources;
    }

    enum DataRequestMethods {
        /* 0 */ Unknown,
        /* 1 */ HttpGet,
        /* 2 */ Rng,
        /* 3 */ HttpPost
    }

    struct DataSource {
        DataRequestMethods method;
        RadonDataTypes resultDataType;
        string url;
        string body;
        string[2][] headers;
        bytes script;
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

    struct RadonSLA {
        uint64 witnessReward;
        uint16 numWitnesses;
        uint64 commitRevealFee;
        uint32 minConsensusPercentage;
        uint64 collateral;
    }

    
    // // ================================================================================================================
    // // --- Internal view/pure methods ---------------------------------------------------------------------------------

    // /// @notice Witnet function that computes the hash of a CBOR-encoded Data Request.
    // /// @param _bytecode CBOR-encoded RADON.
    // function hash(bytes memory _bytecode) internal pure returns (bytes32) {
    //     return sha256(_bytecode);
    // }

}