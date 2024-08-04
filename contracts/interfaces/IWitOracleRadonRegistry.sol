// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRegistry {

    /// Returns the Witnet-compliant RAD bytecode for some Radon Request 
    /// identified by its unique RAD hash. 
    function bytecodeOf(bytes32 radHash) external view returns (bytes memory);

    /// Returns the Witnet-compliant DRO bytecode for some data request object 
    /// made out of the given Radon Request and Radon SLA security parameters. 
    function bytecodeOf(
            bytes32 radHash, 
            Witnet.RadonSLA calldata sla
        ) external view returns (bytes memory);
    
    /// Returns the Witnet-compliant DRO bytecode for some data request object 
    /// made out of the given RAD bytecode and Radon SLA security parameters. 
    function bytecodeOf(
            bytes calldata radBytecode, 
            Witnet.RadonSLA calldata sla
        ) external view returns (bytes memory);
    
    /// Returns the hash of the given Witnet-compliant bytecode. Returned value
    /// can be used to trace back in the Witnet blockchain all past resolutions 
    /// of the given data request payload.
    function hashOf(bytes calldata) external view returns (bytes32);

    function lookupRadonReducer(bytes32 hash) external view returns (Witnet.RadonReducer memory);

    /// Returns the whole Witnet.RadonRequest metadata struct for the given RAD hash value. 
    function lookupRadonRequest(bytes32 radHash) external view returns (Witnet.RadonRequest memory);
    
    /// Returns the Aggregate reducer that is applied to the data extracted from the data sources 
    /// (i.e. Radon Retrievals) whenever the given Radon Request gets solved on the Witnet blockchain. 
    /// Reverts if unknown.
    function lookupRadonRequestAggregator(bytes32 radHash) external view returns (Witnet.RadonReducer memory);
    
    /// Returns the deterministic data type returned by successful resolutions of the given Radon Request. 
    /// Reverts if unknown.
    function lookupRadonRequestResultDataType(bytes32 radHash) external view returns (Witnet.RadonDataTypes);

    /// Returns introspective metadata for the index-th data source of some pre-verified Radon Request. 
    /// Reverts if out of range.
    function lookupRadonRequestRetrievalByIndex(bytes32 radHash, uint256 index) external view returns (Witnet.RadonRetrieval memory);

    /// Returns an array (one or more items) containing the introspective metadata of the given Radon Request's 
    /// data sources (i.e. Radon Retrievals). Reverts if unknown.
    function lookupRadonRequestRetrievals(bytes32 radHash) external view returns (Witnet.RadonRetrieval[] memory);

    /// Returns the Tally reducer that is applied to aggregated values revealed by the witnessing nodes on the 
    /// Witnet blockchain. Reverts if unknown.
    function lookupRadonRequestTally(bytes32 radHash) external view returns (Witnet.RadonReducer memory);

    /// Returns introspective metadata of some previously verified Radon Retrieval 
    /// (i.e. public data source). Reverts if unknown.
    function lookupRadonRetrieval(bytes32 hash) external view returns (Witnet.RadonRetrieval memory);
    
    /// Returns the number of indexed parameters required to be fulfilled when 
    /// eventually using the given Radon Retrieval. Reverts if unknown.
    function lookupRadonRetrievalArgsCount(bytes32 hash) external view returns (uint8);

    /// Returns the type of the data that would be retrieved by the given Radon Retrieval 
    /// (i.e. public data source). Reverts if unknown.
    function lookupRadonRetrievalResultDataType(bytes32 hash) external view returns (Witnet.RadonDataTypes);

    /// Verifies and registers the given sequence of dataset filters and reducing function to be 
    /// potentially used as either Aggregate or Tally reducers within the resolution workflow
    /// of Radon Requests in the Wit/oracle blockchain. Returns a unique hash that identifies the 
    /// given Radon Reducer in the registry. Reverts if unsupported reducing or filtering methods
    /// are specified.
    function verifyRadonReducer(Witnet.RadonReducer calldata reducer) external returns (bytes16 hash);
    
    /// Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals)
    /// and the aggregate and tally Radon Reducers. Returns a unique RAD hash that identifies the 
    /// verified Radon Request. Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - any of passed retrievals is parameterized;
    /// - unsupported reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata retrieveHashes,
            Witnet.RadonReducer calldata aggregate,
            Witnet.RadonReducer calldata tally
        ) external returns (bytes32 radHash);

    /// Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals), 
    /// data sources parameters (if required), and the aggregate and tally Radon Reducers. Returns a unique 
    /// RAD hash that identifies the verified Radon Request.
    /// Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - ranks of passed args don't match with those required by each given retrieval;
    /// - unsupported reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata retrieveHashes,
            string[][] calldata retrieveArgs,
            Witnet.RadonReducer calldata aggregate,
            Witnet.RadonReducer calldata tally
        ) external returns (bytes32 radHash);

    /// Verifies and registers the specified Radon Retrieval (i.e. public data source) into this registry contract. 
    /// Returns a unique retrieval hash that identifies the verified Radon Retrieval.
    /// All parameters but the retrieval method are parameterizable by using embedded wildcard \x\ substrings (with x='0'..'9').
    /// Reverts if:
    /// - unsupported retrieval method is given;
    /// - no URL is provided Http/* requests;
    /// - non-empty strings given on RNG reqs.
    function verifyRadonRetrieval(
            Witnet.RadonRetrievalMethods requestMethod,
            string calldata requestURL,
            string calldata requestBody,
            string[2][] calldata requestHeaders,
            bytes calldata requestRadonScript
        ) external returns (bytes32 hash);
}
