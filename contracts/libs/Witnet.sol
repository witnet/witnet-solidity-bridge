// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetCBOR.sol";

library Witnet {

    using WitnetBuffer for WitnetBuffer.Buffer;
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];

    uint32 constant internal  WIT_1_GENESIS_TIMESTAMP = 0; // TBD    
    uint32 constant internal  WIT_1_SECS_PER_EPOCH = 45;

    uint32  constant internal WIT_2_GENESIS_BEACON_INDEX = 0;       // TBD
    uint32  constant internal WIT_2_GENESIS_BEACON_PREV_INDEX = 0;  // TBD
    bytes24 constant internal WIT_2_GENESIS_BEACON_PREV_ROOT = 0;   // TBD
    bytes16 constant internal WIT_2_GENESIS_BEACON_DDR_TALLIES_MERKLE_ROOT = 0;  // TBD
    bytes16 constant internal WIT_2_GENESIS_BEACON_DRO_TALLIES_MERKLE_ROOT = 0;  // TBD
    uint256 constant internal WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_0 = 0; // TBD
    uint256 constant internal WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_1 = 0; // TBD
    uint256 constant internal WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_2 = 0; // TBD
    uint256 constant internal WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_3 = 0; // TBD
    uint32  constant internal WIT_2_GENESIS_EPOCH = 0;      // TBD
    uint32  constant internal WIT_2_GENESIS_TIMESTAMP = 0;  // TBD
    uint32  constant internal WIT_2_SECS_PER_EPOCH = 20;    // TBD
    uint32  constant internal WIT_2_FAST_FORWARD_COMMITTEE_SIZE = 64; // TBD

    function channel(address wrb) internal view returns (bytes4) {
        return bytes4(keccak256(abi.encode(address(wrb), block.chainid)));
    }

    struct Beacon {
        uint32  index;
        uint32  prevIndex;
        bytes24 prevRoot;
        bytes16 ddrTalliesMerkleRoot;
        bytes16 droTalliesMerkleRoot;
        uint256[4] nextCommitteeAggPubkey;
    }

    struct DataPullReport {
        QueryId queryId;
        QueryHash queryHash;             // KECCAK256(channel | blockhash(block.number - 1) | ...)
        bytes   witDrRelayerSignature;   // ECDSA.signature(queryHash)
        uint32  witDrResultEpoch;
        bytes   witDrResultCborBytes;
        bytes32 witDrTxHash;
    }

    struct DataPushReport {
        QuerySLA witDrSLA;
        bytes32  witDrRadHash;
        uint32   witDrResultEpoch;
        bytes    witDrResultCborBytes;
        bytes32  witDrTxHash;
    }

    struct DataResult {
        RadonDataTypes  dataType;
        WitnetCBOR.CBOR value;
    }
    
    struct FastForward {
        Beacon beacon;
        uint256[2] committeeAggSignature;
        uint256[4][] committeeMissingPubkeys;
    }

    type QueryCapability is bytes20;
    type QueryCapabilityMember is bytes4;
    type QueryBlock is uint64;
    type QueryHash is bytes15;
    type QueryId is uint256;
    type QueryReward is uint72;

    /// Struct containing both request and response data related to every query posted to the Witnet Request Board
    struct Query {
        QueryRequest  request;
        QueryResponse response;
        QuerySLA    slaParams;        // Minimum Service-Level parameters to be committed by the Witnet blockchain.
        QueryBlock  checkpoint;
        QueryHash   hash;             // Unique query hash determined by payload, WRB instance, chain id and EVM's previous block hash.
        QueryReward reward;           // EVM amount in wei eventually to be paid to the legit result reporter.
    }

    /// Possible status of a Witnet query.
    enum QueryStatus {
        Unknown,
        Posted,
        Reported,
        Finalized,
        Delayed,
        Expired,
        Disputed
    }

    struct QueryCallback {
        address consumer;               // consumer contract address to which the query result will be reported
        uint24  gasLimit;               // expected max amount of gas required by the callback method in the consumer contract
    }

    /// Data kept in EVM-storage for every Request posted to the Witnet Request Board.
    struct QueryRequest {
        address  requester;              // EVM address from which the request was posted.
        uint24   callbackGas; uint72 _0; // Max callback gas limit upon response, if a callback is required.
        bytes    radonBytecode;          // Optional: Witnet Data Request bytecode to be solved by the Witnet blockchain.
        bytes32  radonRadHash;           // Optional: Previously verified hash of the Witnet Data Request to be solved.
    }

    /// QueryResponse metadata and result as resolved by the Witnet blockchain.
    struct QueryResponse {
        address reporter; uint64 _0;     // EVM address from which the Data Request result was reported.
        uint32  resultTimestamp;         // Unix timestamp (seconds) at which the data request was resolved in the Witnet blockchain.
        bytes32 resultDrTxHash;          // Unique hash of the commit/reveal act in the Witnet blockchain that resolved the data request.
        bytes   resultCborBytes;         // CBOR-encode result to the request, as resolved in the Witnet blockchain.
        address disputer;
    }

    /// QueryResponse status from a requester's point of view.
    enum QueryResponseStatus {
        Void,
        Awaiting,
        Ready,
        Error,
        Finalizing,
        Delivered,
        Expired
    }

    /// Structure containing all possible SLA security parameters of Wit/2.1 Data Requests
    struct QuerySLA {
        uint16  witResultMaxSize;          // max size permitted to whatever query result may come from the wit/oracle blockchain.
        uint16  witCommitteeCapacity;      // max number of eligibile witnesses in the wit/oracle blockchain for solving some query.
        uint64  witCommitteeUnitaryReward; // unitary reward in nanowits for true witnesses and validators in the wit/oracle blockchain.
        QueryCapability witCapability;     // optional: identifies some pre-established capability-compliant commitee required for solving the query.
    }

    /// Data struct containing the Witnet-provided result to a Data Request.
    // todo: Result -> DataResult
    struct Result {
        bool success;           // Flag stating whether the request could get solved successfully, or not.
        WitnetCBOR.CBOR value;  // Resulting value, in CBOR-serialized bytes.
    }
    
    /// Final query's result status from a requester's point of view.
    enum ResultStatus {
        Void,
        Awaiting,
        Ready,
        Error
    }

    /// Data struct describing an error when trying to fetch a Witnet-provided result to a Data Request.
    struct ResultError {
        ResultErrorCodes code;
        string reason;
    }

    enum ResultErrorCodes {
        /// 0x00: Unknown error. Something went really bad!
        Unknown, 
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Source-specific format error sub-codes ============================================================================
        /// 0x01: At least one of the source scripts is not a valid CBOR-encoded value.
        SourceScriptNotCBOR, 
        /// 0x02: The CBOR value decoded from a source script is not an Array.
        SourceScriptNotArray,
        /// 0x03: The Array value decoded form a source script is not a valid Data Request.
        SourceScriptNotRADON,
        /// 0x04: The request body of at least one data source was not properly formated.
        SourceRequestBody,
        /// 0x05: The request headers of at least one data source was not properly formated.
        SourceRequestHeaders,
        /// 0x06: The request URL of at least one data source was not properly formated.
        SourceRequestURL,
        /// Unallocated
        SourceFormat0x07, SourceFormat0x08, SourceFormat0x09, SourceFormat0x0A, SourceFormat0x0B, SourceFormat0x0C,
        SourceFormat0x0D, SourceFormat0x0E, SourceFormat0x0F, 
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Complexity error sub-codes ========================================================================================
        /// 0x10: The request contains too many sources.
        RequestTooManySources,
        /// 0x11: The script contains too many calls.
        ScriptTooManyCalls,
        /// Unallocated
        Complexity0x12, Complexity0x13, Complexity0x14, Complexity0x15, Complexity0x16, Complexity0x17, Complexity0x18,
        Complexity0x19, Complexity0x1A, Complexity0x1B, Complexity0x1C, Complexity0x1D, Complexity0x1E, Complexity0x1F,

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Lack of support error sub-codes ===================================================================================
        /// 0x20: Some Radon operator code was found that is not supported (1+ args).
        UnsupportedOperator,
        /// 0x21: Some Radon filter opcode is not currently supported (1+ args).
        UnsupportedFilter,
        /// 0x22: Some Radon request type is not currently supported (1+ args).
        UnsupportedHashFunction,
        /// 0x23: Some Radon reducer opcode is not currently supported (1+ args)
        UnsupportedReducer,
        /// 0x24: Some Radon hash function is not currently supported (1+ args).
        UnsupportedRequestType, 
        /// 0x25: Some Radon encoding function is not currently supported (1+ args).
        UnsupportedEncodingFunction,
        /// Unallocated
        Operator0x26, Operator0x27, 
        /// 0x28: Wrong number (or type) of arguments were passed to some Radon operator.
        WrongArguments,
        /// Unallocated
        Operator0x29, Operator0x2A, Operator0x2B, Operator0x2C, Operator0x2D, Operator0x2E, Operator0x2F,
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Retrieve-specific circumstantial error sub-codes ================================================================================
        /// 0x30: A majority of data sources returned an HTTP status code other than 200 (1+ args):
        HttpErrors,
        /// 0x31: A majority of data sources timed out:
        RetrievalsTimeout,
        /// Unallocated
        RetrieveCircumstance0x32, RetrieveCircumstance0x33, RetrieveCircumstance0x34, RetrieveCircumstance0x35,
        RetrieveCircumstance0x36, RetrieveCircumstance0x37, RetrieveCircumstance0x38, RetrieveCircumstance0x39,
        RetrieveCircumstance0x3A, RetrieveCircumstance0x3B, RetrieveCircumstance0x3C, RetrieveCircumstance0x3D,
        RetrieveCircumstance0x3E, RetrieveCircumstance0x3F,
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Scripting-specific runtime error sub-code =========================================================================
        /// 0x40: Math operator caused an underflow.
        MathUnderflow,
        /// 0x41: Math operator caused an overflow.
        MathOverflow,
        /// 0x42: Math operator tried to divide by zero.
        MathDivisionByZero,            
        /// 0x43:Wrong input to subscript call.
        WrongSubscriptInput,
        /// 0x44: Value cannot be extracted from input binary buffer.
        BufferIsNotValue,
        /// 0x45: Value cannot be decoded from expected type.
        Decode,
        /// 0x46: Unexpected empty array.
        EmptyArray,
        /// 0x47: Value cannot be encoded to expected type.
        Encode,
        /// 0x48: Failed to filter input values (1+ args).
        Filter,
        /// 0x49: Failed to hash input value.
        Hash,
        /// 0x4A: Mismatching array ranks.
        MismatchingArrays,
        /// 0x4B: Failed to process non-homogenous array.
        NonHomegeneousArray,
        /// 0x4C: Failed to parse syntax of some input value, or argument.
        Parse,
        /// 0x4E: Parsing logic limits were exceeded.
        ParseOverflow,
        /// 0x4F: Unallocated
        ScriptError0x4F,
    
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Actual first-order result error codes =============================================================================
        /// 0x50: Not enough reveals were received in due time:
        InsufficientReveals,
        /// 0x51: No actual reveal majority was reached on tally stage:
        InsufficientMajority,
        /// 0x52: Not enough commits were received before tally stage:
        InsufficientCommits,
        /// 0x53: Generic error during tally execution (to be deprecated after WIP #0028)
        TallyExecution,
        /// 0x54: A majority of data sources could either be temporarily unresponsive or failing to report the requested data:
        CircumstantialFailure,
        /// 0x55: At least one data source is inconsistent when queried through multiple transports at once:
        InconsistentSources,
        /// 0x56: Any one of the (multiple) Retrieve, Aggregate or Tally scripts were badly formated:
        MalformedDataRequest,
        /// 0x57: Values returned from a majority of data sources don't match the expected schema:
        MalformedQueryResponses,
        /// Unallocated:    
        OtherError0x58, OtherError0x59, OtherError0x5A, OtherError0x5B, OtherError0x5C, OtherError0x5D, OtherError0x5E, 
        /// 0x5F: Size of serialized tally result exceeds allowance:
        OversizedTallyResult,

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Inter-stage runtime error sub-codes ===============================================================================
        /// 0x60: Data aggregation reveals could not get decoded on the tally stage:
        MalformedReveals,
        /// 0x61: The result to data aggregation could not get encoded:
        EncodeReveals,  
        /// 0x62: A mode tie ocurred when calculating some mode value on the aggregation or the tally stage:
        ModeTie, 
        /// Unallocated:
        OtherError0x63, OtherError0x64, OtherError0x65, OtherError0x66, OtherError0x67, OtherError0x68, OtherError0x69, 
        OtherError0x6A, OtherError0x6B, OtherError0x6C, OtherError0x6D, OtherError0x6E, OtherError0x6F,
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Runtime access error sub-codes ====================================================================================
        /// 0x70: Tried to access a value from an array using an index that is out of bounds (1+ args):
        ArrayIndexOutOfBounds,
        /// 0x71: Tried to access a value from a map using a key that does not exist (1+ args):
        MapKeyNotFound,
        /// 0X72: Tried to extract value from a map using a JSON Path that returns no values (+1 args):
        JsonPathNotFound,
        /// Unallocated:
        OtherError0x73, OtherError0x74, OtherError0x75, OtherError0x76, OtherError0x77, OtherError0x78, 
        OtherError0x79, OtherError0x7A, OtherError0x7B, OtherError0x7C, OtherError0x7D, OtherError0x7E, OtherError0x7F, 
        OtherError0x80, OtherError0x81, OtherError0x82, OtherError0x83, OtherError0x84, OtherError0x85, OtherError0x86, 
        OtherError0x87, OtherError0x88, OtherError0x89, OtherError0x8A, OtherError0x8B, OtherError0x8C, OtherError0x8D, 
        OtherError0x8E, OtherError0x8F, OtherError0x90, OtherError0x91, OtherError0x92, OtherError0x93, OtherError0x94, 
        OtherError0x95, OtherError0x96, OtherError0x97, OtherError0x98, OtherError0x99, OtherError0x9A, OtherError0x9B,
        OtherError0x9C, OtherError0x9D, OtherError0x9E, OtherError0x9F, OtherError0xA0, OtherError0xA1, OtherError0xA2, 
        OtherError0xA3, OtherError0xA4, OtherError0xA5, OtherError0xA6, OtherError0xA7, OtherError0xA8, OtherError0xA9, 
        OtherError0xAA, OtherError0xAB, OtherError0xAC, OtherError0xAD, OtherError0xAE, OtherError0xAF, OtherError0xB0,
        OtherError0xB1, OtherError0xB2, OtherError0xB3, OtherError0xB4, OtherError0xB5, OtherError0xB6, OtherError0xB7,
        OtherError0xB8, OtherError0xB9, OtherError0xBA, OtherError0xBB, OtherError0xBC, OtherError0xBD, OtherError0xBE,
        OtherError0xBF, OtherError0xC0, OtherError0xC1, OtherError0xC2, OtherError0xC3, OtherError0xC4, OtherError0xC5,
        OtherError0xC6, OtherError0xC7, OtherError0xC8, OtherError0xC9, OtherError0xCA, OtherError0xCB, OtherError0xCC,
        OtherError0xCD, OtherError0xCE, OtherError0xCF, OtherError0xD0, OtherError0xD1, OtherError0xD2, OtherError0xD3,
        OtherError0xD4, OtherError0xD5, OtherError0xD6, OtherError0xD7, OtherError0xD8, OtherError0xD9, OtherError0xDA,
        OtherError0xDB, OtherError0xDC, OtherError0xDD, OtherError0xDE, OtherError0xDF,
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Inter-client generic error codes ==================================================================================
        /// Data requests that cannot be relayed into the Witnet blockchain should be reported
        /// with one of these errors. 
        /// 0xE0: Requests that cannot be parsed must always get this error as their result.
        BridgeMalformedDataRequest,
        /// 0xE1: Witnesses exceeds 100
        BridgePoorIncentives,
        /// 0xE2: The request is rejected on the grounds that it may cause the submitter to spend or stake an
        /// amount of value that is unjustifiably high when compared with the reward they will be getting
        BridgeOversizedTallyResult,
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// Unallocated =======================================================================================================
        OtherError0xE3, OtherError0xE4, OtherError0xE5, OtherError0xE6, OtherError0xE7, OtherError0xE8, OtherError0xE9,
        OtherError0xEA, OtherError0xEB, OtherError0xEC, OtherError0xED, OtherError0xEE, OtherError0xEF, OtherError0xF0,
        OtherError0xF1, OtherError0xF2, OtherError0xF3, OtherError0xF4, OtherError0xF5, OtherError0xF6, OtherError0xF7,
        OtherError0xF8, OtherError0xF9, OtherError0xFA, OtherError0xFB, OtherError0xFC, OtherError0xFD, OtherError0xFE,
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /// 0xFF: Some tally error is not intercepted but it should (0+ args)
        UnhandledIntercept
    }

    /// Possible types either processed by Witnet Radon Scripts or included within results to Witnet Data Requests.
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

    /// Structure defining some data filtering that can be applied at the Aggregation or the Tally stages
    /// within a Witnet Data Request resolution workflow.
    struct RadonFilter {
        RadonFilterOpcodes opcode;
        bytes cborArgs;
    }

    /// Filtering methods currently supported on the Witnet blockchain. 
    enum RadonFilterOpcodes {
        /* 0x00 */ Reserved0x00, //GreaterThan,
        /* 0x01 */ Reserved0x01, //LessThan,
        /* 0x02 */ Reserved0x02, //Equals,
        /* 0x03 */ Reserved0x03, //AbsoluteDeviation,
        /* 0x04 */ Reserved0x04, //RelativeDeviation
        /* 0x05 */ StandardDeviation,
        /* 0x06 */ Reserved0x06, //Top,
        /* 0x07 */ Reserved0x07, //Bottom,
        /* 0x08 */ Mode,
        /* 0x09 */ Reserved0x09  //LessOrEqualThan
    }

    /// Structure defining the array of filters and reducting function to be applied at either the Aggregation
    /// or the Tally stages within a Witnet Data Request resolution workflow.
    struct RadonReducer {
        RadonReduceOpcodes opcode;
        RadonFilter[] filters;
    }

    /// Reducting functions currently supported on the Witnet blockchain.
    enum RadonReduceOpcodes {
        /* 0x00 */ Reserved0x00, //Minimum,
        /* 0x01 */ Reserved0x01, //Maximum,
        /* 0x02 */ Mode,
        /* 0x03 */ AverageMean,
        /* 0x04 */ Reserved0x04, //AverageMeanWeighted,
        /* 0x05 */ AverageMedian,
        /* 0x06 */ Reserved0x06, //AverageMedianWeighted,
        /* 0x07 */ StandardDeviation,
        /* 0x08 */ Reserved0x08, //AverageDeviation,
        /* 0x09 */ Reserved0x09, //MedianDeviation,
        /* 0x0A */ Reserved0x10, //MaximumDeviation,
        /* 0x0B */ ConcatenateAndHash
    }
    
    /// Structure containing the Retrieve-Attestation-Delivery parts of a Witnet-compliant Data Request.
    struct RadonRequest {
        RadonRetrieval[] retrieve;
        RadonReducer aggregate;
        RadonReducer tally;
    }

    /// Structure containing all the parameters that fully describe a Witnet Radon Retrieval within a Witnet Data Request.
    struct RadonRetrieval {
        uint8 argsCount;
        RadonRetrievalMethods method;
        RadonDataTypes dataType;
        string url;
        string body;
        string[2][] headers;
        bytes radonScript;
    }

    /// Possible Radon retrieval methods that can be used within a Radon Retrieval. 
    enum RadonRetrievalMethods {
        /* 0 */ Unknown,
        /* 1 */ HttpGet,
        /* 2 */ RNG,
        /* 3 */ HttpPost,
        /* 4 */ HttpHead
    }

    /// Structure containing all possible SLA security parameters of a Witnet-compliant Data Request.

    struct RadonSLAv1 {
        uint8 numWitnesses;
        uint8 minConsensusPercentage;
        uint64 witnessReward;
        uint64 witnessCollateral;
        uint64 minerCommitRevealFee;
    }


    /// =======================================================================
    /// --- Beacon helper functions ------------------------------------

    function equals(Beacon storage self, Beacon calldata other)
        internal view returns (bool)
    {
        return (
            root(self) == root(other)
        );
    }

    function root(Beacon calldata self) internal pure returns (bytes24) {
        return bytes24(keccak256(abi.encode(
            self.index,
            self.prevIndex,
            self.prevRoot,
            self.ddrTalliesMerkleRoot,
            self.droTalliesMerkleRoot,
            self.nextCommitteeAggPubkey
        )));
    }
    
    function root(Beacon storage self) internal view returns (bytes24) {
        return bytes24(keccak256(abi.encode(
            self.index,
            self.prevIndex,
            self.prevRoot,
            self.ddrTalliesMerkleRoot,
            self.droTalliesMerkleRoot,
            self.nextCommitteeAggPubkey
        )));
    }


    /// =======================================================================
    /// --- FastForward helper functions -------------------------------

    function head(FastForward[] calldata rollup)
        internal pure returns (Beacon calldata)
    {
        return rollup[rollup.length - 1].beacon;
    }


    /// ===============================================================================================================
    /// --- Query* helper methods -------------------------------------------------------------------------------------

    function hashify(QueryHash hash) internal pure returns (bytes32) {
        return keccak256(abi.encode(QueryHash.unwrap(hash)));
    }

    function hashify(QueryId _queryId, bytes32 _radHash, bytes32 _slaHash) internal view returns (Witnet.QueryHash) {
        return Witnet.QueryHash.wrap(bytes15(
            keccak256(abi.encode(
                channel(address(this)), 
                blockhash(block.number - 1),
                _queryId, _radHash, _slaHash
            ))
        ));
    }

    function hashify(QuerySLA memory querySLA) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            querySLA.witResultMaxSize,
            querySLA.witCommitteeCapacity,
            querySLA.witCommitteeUnitaryReward,
            querySLA.witCapability
        ));
    }


    /// ===============================================================================================================
    /// --- *Report helper methods ------------------------------------------------------------------------------------

    function queryRelayer(DataPullReport calldata self) internal pure returns (address) {
        return recoverAddr(
            self.witDrRelayerSignature, 
            hashify(self.queryHash)
        );
    }

    function tallyHash(DataPullReport calldata self) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            self.queryHash,
            self.witDrRelayerSignature,
            self.witDrTxHash,
            self.witDrResultEpoch,
            self.witDrResultCborBytes
        ));
    }

    function tallyHash(DataPushReport calldata self) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            self.witDrRadHash,
            self.witDrSLA,
            self.witDrTxHash,
            self.witDrResultEpoch,
            self.witDrResultCborBytes
        ));
    }


    /// ===============================================================================================================
    /// --- 'Result' helper methods ----------------------------------------------------------------------------

    modifier _isReady(Result memory result) {
        require(result.success, "Witnet: tried to decode value from errored result.");
        _;
    }

    /// @dev Decode an address from the Result's CBOR value.
    function asAddress(Result memory result)
        internal pure
        _isReady(result)
        returns (address)
    {
        if (result.value.majorType == uint8(WitnetCBOR.MAJOR_TYPE_BYTES)) {
            return toAddress(result.value.readBytes());
        } else {
            revert("WitnetLib: reading address from string not yet supported.");
        }
    }

    /// @dev Decode a `bool` value from the Result's CBOR value.
    function asBool(Result memory result)
        internal pure
        _isReady(result)
        returns (bool)
    {
        return result.value.readBool();
    }

    /// @dev Decode a `bytes` value from the Result's CBOR value.
    function asBytes(Result memory result)
        internal pure
        _isReady(result)
        returns(bytes memory)
    {
        return result.value.readBytes();
    }

    /// @dev Decode a `bytes4` value from the Result's CBOR value.
    function asBytes4(Result memory result)
        internal pure
        _isReady(result)
        returns (bytes4)
    {
        return toBytes4(asBytes(result));
    }

    /// @dev Decode a `bytes32` value from the Result's CBOR value.
    function asBytes32(Result memory result)
        internal pure
        _isReady(result)
        returns (bytes32)
    {
        return toBytes32(asBytes(result));
    }

    /// @notice Returns the Result's unread CBOR value.
    function asCborValue(Result memory result)
        internal pure
        _isReady(result)
        returns (WitnetCBOR.CBOR memory)
    {
        return result.value;
    }

    /// @notice Decode array of CBOR values from the Result's CBOR value. 
    function asCborArray(Result memory result)
        internal pure
        _isReady(result)
        returns (WitnetCBOR.CBOR[] memory)
    {
        return result.value.readArray();
    }

    /// @dev Decode a fixed16 (half-precision) numeric value from the Result's CBOR value.
    /// @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values.
    /// by 5 decimal orders so as to get a fixed precision of 5 decimal positions, which should be OK for most `fixed16`.
    /// use cases. In other words, the output of this method is 10,000 times the actual value, encoded into an `int32`.
    function asFixed16(Result memory result)
        internal pure
        _isReady(result)
        returns (int32)
    {
        return result.value.readFloat16();
    }

    /// @dev Decode an array of fixed16 values from the Result's CBOR value.
    function asFixed16Array(Result memory result)
        internal pure
        _isReady(result)
        returns (int32[] memory)
    {
        return result.value.readFloat16Array();
    }

    /// @dev Decode an `int64` value from the Result's CBOR value.
    function asInt(Result memory result)
        internal pure
        _isReady(result)
        returns (int)
    {
        return result.value.readInt();
    }

    /// @dev Decode an array of integer numeric values from a Result as an `int[]` array.
    /// @param result An instance of Result.
    /// @return The `int[]` decoded from the Result.
    function asIntArray(Result memory result)
        internal pure
        _isReady(result)
        returns (int[] memory)
    {
        return result.value.readIntArray();
    }

    /// @dev Decode a `string` value from the Result's CBOR value.
    /// @param result An instance of Result.
    /// @return The `string` decoded from the Result.
    function asText(Result memory result)
        internal pure
        _isReady(result)
        returns(string memory)
    {
        return result.value.readString();
    }

    /// @dev Decode an array of strings from the Result's CBOR value.
    /// @param result An instance of Result.
    /// @return The `string[]` decoded from the Result.
    function asTextArray(Result memory result)
        internal pure
        _isReady(result)
        returns (string[] memory)
    {
        return result.value.readStringArray();
    }

    /// @dev Decode a `uint64` value from the Result's CBOR value.
    /// @param result An instance of Result.
    /// @return The `uint` decoded from the Result.
    function asUint(Result memory result)
        internal pure
        _isReady(result)
        returns (uint)
    {
        return result.value.readUint();
    }

    /// @dev Decode an array of `uint64` values from the Result's CBOR value.
    /// @param result An instance of Result.
    /// @return The `uint[]` decoded from the Result.
    function asUintArray(Result memory result)
        internal pure
        returns (uint[] memory)
    {
        return result.value.readUintArray();
    }


    /// ===============================================================================================================
    /// --- ResultErrorCodes helper methods --------------------------------------------------------------------

    function isCircumstantial(ResultErrorCodes self) internal pure returns (bool) {
        return (self == ResultErrorCodes.CircumstantialFailure);
    }

    function isRetriable(ResultErrorCodes self) internal pure returns (bool) {
        return (
            lackOfConsensus(self)
                || isCircumstantial(self)
                || poorIncentives(self)
        );
    }

    function lackOfConsensus(ResultErrorCodes self) internal pure returns (bool) {
        return (
            self == ResultErrorCodes.InsufficientCommits
                || self == ResultErrorCodes.InsufficientMajority
                || self == ResultErrorCodes.InsufficientReveals
        );
    }

    function poorIncentives(ResultErrorCodes self) internal pure returns (bool) {
        return (
            self == ResultErrorCodes.OversizedTallyResult
                || self == ResultErrorCodes.InsufficientCommits
                || self == ResultErrorCodes.BridgePoorIncentives
                || self == ResultErrorCodes.BridgeOversizedTallyResult
        );
    }


    /// ========================================================================================================
    /// --- 'QuerySLA' helper methods --------------------------------------------------------------------------

    function equalOrGreaterThan(QuerySLA calldata self, QuerySLA storage stored) internal view returns (bool) {
        return (
            QueryCapability.unwrap(self.witCapability) == QueryCapability.unwrap(stored.witCapability)
                && self.witCommitteeCapacity >= stored.witCommitteeCapacity
                && self.witCommitteeUnitaryReward >= stored.witCommitteeUnitaryReward 
                && self.witResultMaxSize <= stored.witResultMaxSize
        );
    }

    function isValid(QuerySLA memory self) internal pure returns (bool) {
        return (
            self.witResultMaxSize > 0
                && self.witCommitteeUnitaryReward > 0
                && self.witCommitteeCapacity > 0
                && (QueryCapability.unwrap(self.witCapability) != 0 || self.witCommitteeCapacity <= 127)
        );
    }

    function toV1(QuerySLA calldata self) internal pure returns (RadonSLAv1 memory) {
        return RadonSLAv1({
            numWitnesses: uint8(self.witCommitteeCapacity),
            minConsensusPercentage: 66,
            witnessReward: self.witCommitteeUnitaryReward,
            witnessCollateral: self.witCommitteeUnitaryReward * 100,
            minerCommitRevealFee: self.witCommitteeUnitaryReward / self.witCommitteeCapacity
        });
    }

    function witTotalReward(QuerySLA storage self) internal view returns (uint64) {
        return self.witCommitteeUnitaryReward / (self.witCommitteeCapacity + 3);
    }


    /// ===============================================================================================================
    /// --- 'bytes*' helper methods -----------------------------------------------------------------------------------

    function merkleHash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return (a < b
            ? _merkleHash(a, b)
            : _merkleHash(b, a)
        );
    }

    function merkleRoot(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32 _root) {
        _root = leaf;
        for (uint _ix = 0; _ix < proof.length; _ix ++) {
            _root = merkleHash(_root, proof[_ix]);
        }
    }

    function radHash(bytes calldata bytecode) internal pure returns (bytes32) {
        return keccak256(bytecode);
    }

    function recoverAddr(bytes memory signature, bytes32 hash_)
        internal pure 
        returns (address)
    {
        if (signature.length != 65) {
            return (address(0));
        }
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return address(0);
        }
        if (v != 27 && v != 28) {
            return address(0);
        }
        return ecrecover(hash_, v, r, s);
    }


    /// @dev Transform given bytes into a Result instance.
    /// @param cborBytes Raw bytes representing a CBOR-encoded value.
    /// @return A `Result` instance.
    function toWitnetResult(bytes memory cborBytes)
        internal pure
        returns (Result memory)
    {
        WitnetCBOR.CBOR memory cborValue = WitnetCBOR.fromBytes(cborBytes);
        return _resultFromCborValue(cborValue);
    }

    function toAddress(bytes memory _value) internal pure returns (address) {
        return address(toBytes20(_value));
    }

    function toBytes4(bytes memory _value) internal pure returns (bytes4) {
        return bytes4(toFixedBytes(_value, 4));
    }
    
    function toBytes20(bytes memory _value) internal pure returns (bytes20) {
        return bytes20(toFixedBytes(_value, 20));
    }
    
    function toBytes32(bytes memory _value) internal pure returns (bytes32) {
        return toFixedBytes(_value, 32);
    }

    function intoMemArray(bytes32[1] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 1, _values), (bytes32[]));
    }

    function intoMemArray(bytes32[2] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 2, _values), (bytes32[]));
    }

    function intoMemArray(bytes32[3] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 3, _values), (bytes32[]));
    }

    function intoMemArray(bytes32[4] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 4, _values), (bytes32[]));
    }

    function intoMemArray(bytes32[5] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 5, _values), (bytes32[]));
    }

    function intoMemArray(bytes32[6] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 6, _values), (bytes32[]));
    }

    function intoMemArray(bytes32[7] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 7, _values), (bytes32[]));
    }

    function intoMemArray(bytes32[8] memory _values) internal pure returns (bytes32[] memory) {
        return abi.decode(abi.encode(uint256(32), 8, _values), (bytes32[]));
    }

    function toFixedBytes(bytes memory _value, uint8 _numBytes)
        internal pure
        returns (bytes32 _bytes32)
    {
        assert(_numBytes <= 32);
        unchecked {
            uint _len = _value.length > _numBytes ? _numBytes : _value.length;
            for (uint _i = 0; _i < _len; _i ++) {
                _bytes32 |= bytes32(_value[_i] & 0xff) >> (_i * 8);
            }
        }
    }


    /// ===============================================================================================================
    /// --- 'string' helper methods -----------------------------------------------------------------------------------

    function toLowerCase(string memory str)
        internal pure
        returns (string memory)
    {
        bytes memory lowered = new bytes(bytes(str).length);
        unchecked {
            for (uint i = 0; i < lowered.length; i ++) {
                uint8 char = uint8(bytes(str)[i]);
                if (char >= 65 && char <= 90) {
                    lowered[i] = bytes1(char + 32);
                } else {
                    lowered[i] = bytes1(char);
                }
            }
        }
        return string(lowered);
    }

    /// @notice Converts bytes32 into string.
    function toString(bytes32 _bytes32)
        internal pure
        returns (string memory)
    {
        bytes memory _bytes = new bytes(_toStringLength(_bytes32));
        for (uint _i = 0; _i < _bytes.length;) {
            _bytes[_i] = _bytes32[_i];
            unchecked {
                _i ++;
            }
        }
        return string(_bytes);
    }

    function tryUint(string memory str)
        internal pure
        returns (uint res, bool)
    {
        unchecked {
            for (uint256 i = 0; i < bytes(str).length; i++) {
                if (
                    (uint8(bytes(str)[i]) - 48) < 0
                        || (uint8(bytes(str)[i]) - 48) > 9
                ) {
                    return (0, false);
                }
                res += (uint8(bytes(str)[i]) - 48) * 10 ** (bytes(str).length - i - 1);
            }
            return (res, true);
        }
    }


    /// ===============================================================================================================
    /// --- 'uint*' helper methods ------------------------------------------------------------------------------------

    function determineBeaconIndexFromEpoch(uint32 epoch) internal pure returns (uint32) {
        return epoch / 10;
    }
    
    function determineBeaconIndexFromTimestamp(uint32 timestamp) internal pure returns (uint32) {
        return determineBeaconIndexFromEpoch(
            determineEpochFromTimestamp(
                timestamp
            )
        );
    }

    function determineEpochFromTimestamp(uint32 timestamp) internal pure returns (uint32) {
        if (timestamp > WIT_2_GENESIS_TIMESTAMP) {
            return (
                WIT_2_GENESIS_EPOCH
                    + (timestamp - WIT_2_GENESIS_TIMESTAMP)
                        / WIT_2_SECS_PER_EPOCH
            );
        } else if (timestamp > WIT_1_GENESIS_TIMESTAMP) {
            return (
                (timestamp - WIT_1_GENESIS_TIMESTAMP)
                    / WIT_1_SECS_PER_EPOCH
            );
        } else {
            return 0;
        }
    }

    function determineTimestampFromEpoch(uint32 epoch) internal pure returns (uint32) {
        if (epoch >= WIT_2_GENESIS_EPOCH) {
            return (
                WIT_2_GENESIS_TIMESTAMP
                    + (WIT_2_SECS_PER_EPOCH * (
                        epoch
                            - WIT_2_GENESIS_EPOCH)
                    )
            );
        } else return (
            WIT_1_SECS_PER_EPOCH
                * epoch
        );
    }

    /// Generates a pseudo-random uint32 number uniformly distributed within the range `[0 .. range)`, based on
    /// the given `nonce` and `seed` values. 
    function randomUniformUint32(uint32 range, uint256 nonce, bytes32 seed)
        internal pure 
        returns (uint32) 
    {
        uint256 _number = uint256(
            keccak256(
                abi.encode(seed, nonce)
            )
        ) & uint256(2 ** 224 - 1);
        return uint32((_number * range) >> 224);
    }

    /// @notice Convert a `uint8` into a 2 characters long `string` representing its two less significant hexadecimal values.
    function toHexString(uint8 _u)
        internal pure
        returns (string memory)
    {
        bytes memory b2 = new bytes(2);
        uint8 d0 = uint8(_u / 16) + 48;
        uint8 d1 = uint8(_u % 16) + 48;
        if (d0 > 57)
            d0 += 7;
        if (d1 > 57)
            d1 += 7;
        b2[0] = bytes1(d0);
        b2[1] = bytes1(d1);
        return string(b2);
    }

    /// @notice Convert a `uint8` into a 1, 2 or 3 characters long `string` representing its.
    /// three less significant decimal values.
    function toString(uint8 _u)
        internal pure
        returns (string memory)
    {
        if (_u < 10) {
            bytes memory b1 = new bytes(1);
            b1[0] = bytes1(uint8(_u) + 48);
            return string(b1);
        } else if (_u < 100) {
            bytes memory b2 = new bytes(2);
            b2[0] = bytes1(uint8(_u / 10) + 48);
            b2[1] = bytes1(uint8(_u % 10) + 48);
            return string(b2);
        } else {
            bytes memory b3 = new bytes(3);
            b3[0] = bytes1(uint8(_u / 100) + 48);
            b3[1] = bytes1(uint8(_u % 100 / 10) + 48);
            b3[2] = bytes1(uint8(_u % 10) + 48);
            return string(b3);
        }
    }

    /// @notice Convert a `uint` into a string` representing its value.
    function toString(uint v)
        internal pure 
        returns (string memory)
    {
        uint maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        do {
            uint8 remainder = uint8(v % 10);
            v = v / 10;
            reversed[i ++] = bytes1(48 + remainder);
        } while (v != 0);
        bytes memory buf = new bytes(i);
        for (uint j = 1; j <= i; j ++) {
            buf[j - 1] = reversed[i - j];
        }
        return string(buf);
    }


    /// ===============================================================================================================
    /// --- Witnet library private methods ----------------------------------------------------------------------------

    function _merkleHash(bytes32 _a, bytes32 _b) private pure returns (bytes32 _hash) {
        assembly {
            mstore(0x0, _a)
            mstore(0x20, _b)
            _hash := keccak256(0x0, 0x40)
        }
    }

    /// @dev Decode a CBOR value into a Result instance.
    function _resultFromCborValue(WitnetCBOR.CBOR memory cbor)
        private pure
        returns (Result memory)    
    {
        // Witnet uses CBOR tag 39 to represent RADON error code identifiers.
        // [CBOR tag 39] Identifiers for CBOR: https://github.com/lucas-clemente/cbor-specs/blob/master/id.md
        bool success = cbor.tag != 39;
        return Result(success, cbor);
    }

    /// @dev Calculate length of string-equivalent to given bytes32.
    function _toStringLength(bytes32 _bytes32)
        private pure
        returns (uint _length)
    {
        for (; _length < 32; ) {
            if (_bytes32[_length] == 0) {
                break;
            }
            unchecked {
                _length ++;
            }
        }
    }
}
