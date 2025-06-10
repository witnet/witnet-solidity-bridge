// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRegistry {

    /// @notice Returns the Witnet-compliant DRO bytecode for some data request object 
    /// made out of the given Radon Request and Radon SLA security parameters. 
    function bytecodeOf(
            Witnet.RadonHash radonRequestHash, 
            Witnet.QuerySLA calldata queryParams
        ) external view returns (bytes memory);
    
    /// @notice Returns the Witnet-compliant DRO bytecode for some data request object 
    /// made out of the given RAD bytecode and Radon SLA security parameters. 
    function bytecodeOf(
            bytes calldata radonRequestBytecode, 
            Witnet.QuerySLA calldata queryParams
        ) external view returns (bytes memory);

    /// @notice Returns the hash of the given Witnet-compliant bytecode. Returned value
    /// can be used to trace back in the Witnet blockchain all past resolutions 
    /// of the given data request payload.
    function hashOf(bytes calldata) external view returns (Witnet.RadonHash);

    /// @notice Tells whether the specified Radon Reducer has been formally verified into the registry.
    function isVerifiedRadonReducer(bytes32) external view returns (bool);
    
    /// @notice Tells whether the given Radon Hash has been formally verified into the registry.
    function isVerifiedRadonRequest(Witnet.RadonHash) external view returns (bool);
    
    /// @notice Tells whether the specified Radon Retrieval has been formally verified into the registry.
    function isVerifiedRadonRetrieval(bytes32) external view returns (bool);
    
    /// @notice Returns the whole Witnet.RadonReducer metadata struct for the given hash.
    /// @dev Reverts if unknown.
    function lookupRadonReducer(bytes32 hash) external view returns (Witnet.RadonReducer memory);

    // /// @notice Returns the whole Witnet.RadonRequest metadata struct for the given RAD hash value. 
    // /// @dev Reverts if unknown.
    // function lookupRadonRequest(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonRequest memory);

    /// @notice Returns the Witnet-compliant RAD bytecode for some Radon Request 
    /// identified by its unique RAD hash. 
    function lookupRadonRequestBytecode(Witnet.RadonHash radonRequestHash) external view returns (bytes memory);

    /// @notice Returns the Tally reducer that is applied to aggregated values revealed by the witnessing nodes on the 
    /// Witnet blockchain. 
    /// @dev Reverts if unknown.
    function lookupRadonRequestCrowdAttestationTally(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonReducer memory);
    
    /// @notice Returns the deterministic data type returned by successful resolutions of the given Radon Request. 
    /// @dev Reverts if unknown.
    function lookupRadonRequestResultDataType(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonDataTypes);

    /// @notice Returns introspective metadata for the index-th data source of some pre-verified Radon Request. 
    /// @dev Reverts if out of range.
    // function lookupRadonRequestRetrievalByIndex(Witnet.RadonHash radonRequestHash, uint256 index) external view returns (Witnet.RadonRetrieval memory);

    /// @notice Returns an array (one or more items) containing the introspective metadata of the given Radon Request's 
    /// data sources (i.e. Radon Retrievals). 
    /// @dev Reverts if unknown.
    function lookupRadonRequestRetrievals(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonRetrieval[] memory);

    /// @notice Returns the Aggregate reducer that is applied to the data extracted from the data sources 
    /// (i.e. Radon Retrievals) whenever the given Radon Request gets solved on the Witnet blockchain. 
    /// @dev Reverts if unknown.
    function lookupRadonRequestRetrievalsAggregator(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonReducer memory);

    function lookupRadonRequestRetrievalsCount(Witnet.RadonHash radonRequestHash) external view returns (uint8);

    /// @notice Returns introspective metadata of some previously verified Radon Retrieval (i.e. public data source). 
    ///@dev Reverts if unknown.
    function lookupRadonRetrieval(bytes32 hash) external view returns (Witnet.RadonRetrieval memory);
    
    /// @notice Returns the number of indexed parameters required to be fulfilled when 
    /// eventually using the given Radon Retrieval. 
    /// @dev Reverts if unknown.
    function lookupRadonRetrievalArgsCount(bytes32 hash) external view returns (uint8);

    /// @notice Returns the type of the data that would be retrieved by the given Radon Retrieval 
    /// (i.e. public data source). 
    /// @dev Reverts if unknown.
    function lookupRadonRetrievalResultDataType(bytes32 hash) external view returns (Witnet.RadonDataTypes);

    /// @notice Verifies and registers the given sequence of dataset filters and reducing function to be 
    /// potentially used as either Aggregate or Tally reducers within the resolution workflow
    /// of Radon Requests in the Wit/Oracle blockchain. Returns a unique hash that identifies the 
    /// given Radon Reducer in the registry. 
    /// @dev Reverts if unsupported reducing or filtering methods are specified.
    function verifyRadonReducer(Witnet.RadonReducer calldata reducer) external returns (bytes32 hash);
    
    /// @notice Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals)
    /// and the aggregate and tally Radon Reducers. Returns a unique RAD hash that identifies the 
    /// verified Radon Request. 
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - any of passed retrievals is parameterized;
    /// - unsupported reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata radonRetrieveHashes,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowsAttestationTally
        ) external returns (Witnet.RadonHash radonRequestHash);

    /// @notice Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals), 
    /// data sources parameters (if required), and some pre-verified aggregate and tally Radon Reducers. 
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - ranks of passed args don't match with those required by each given retrieval;
    /// - unverified reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata retrieveHashes,
            bytes32 aggregateReducerHash,
            bytes32 tallyReducerHash
        ) external returns (Witnet.RadonHash radonRequestHash);

    /// @notice Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals), 
    /// data sources parameters (if required), and the aggregate and tally Radon Reducers. Returns a unique 
    /// RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - ranks of passed args don't match with those required by each given retrieval;
    /// - unsupported reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata radonRetrieveHashes,
            string[][] calldata radonRetrieveArgs,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        ) external returns (Witnet.RadonHash radonRequestHash);

    /// @notice Verifies and registers the specified Radon Request out of a single modal retrieval where first 
    /// parameter corresponds to data provider's URL, an array of data providers (i.e. URLs), and an array
    /// of parmeter values common to all data providers. Some pre-verified aggregate and tally Radon Reducers
    /// must also be provided. Returns a unique RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrieval is passed;
    /// - ranks of passed args don't match with those expected by given retrieval, after replacing the data provider URL.
    /// - unverified reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata radonRetrieveHashes,
            string[][] calldata radonRetrieveArgs,
            bytes32 dataSourcesAggregatorHash,
            bytes32 crowdAttestationTallyHash
        ) external returns (Witnet.RadonHash radonRequestHash);

    function verifyRadonRequest(
            bytes32 commonRetrieveHash,
            string[] calldata commonRetrieveArgs,
            string[] calldata dataProviders,
            bytes32 dataSourcesAggregatorHash,
            bytes32 crowdAttestationTallyHash
        ) external returns (Witnet.RadonHash radonRequestHash);

    /// @notice Verifies and registers the specified Radon Retrieval (i.e. public data source) into this registry contract. 
    /// Returns a unique retrieval hash that identifies the verified Radon Retrieval.
    /// All parameters but the retrieval method are parameterizable by using embedded wildcard \x\ substrings (with x='0'..'9').
    /// @dev Reverts if:
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

//     /// Verifies a new Radon Retrieval by specifying the value to the highest indexed parameter of an already existing one.
//     /// Returns the unique hash that identifies the resulting Radon Retrieval.
//     /// Reverts if an unverified retrieval hash is passed.
//     function verifyRadonRetrieval(
//             bytes32 retrieveHash,
//             string calldata lastArgValue
//         ) external returns (bytes32 hash);
// }
}