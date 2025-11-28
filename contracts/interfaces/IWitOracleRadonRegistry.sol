// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRegistry {

    /// @notice Returns the Witnet-compliant DRO bytecode for some previously verified Radon Request
    /// and the query parameters.
    /// @dev Reverts if unknown.
    function bytecodeOf(
            Witnet.RadonHash radonRequestHash, 
            Witnet.QuerySLA calldata queryParams
        ) external view returns (bytes memory);
    
    /// @notice Returns the Witnet-compliant DRO bytecode made out of the given
    /// Radon Request bytecode and query parameters.
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

    /// @notice Returns an array (one or more items) containing the introspective metadata of the given Radon Request's 
    /// data sources (i.e. Radon Retrievals). 
    /// @dev Reverts if unknown.
    function lookupRadonRequestRetrievals(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonRetrieval[] memory);

    /// @notice Returns the Aggregate reducer that is applied to the data extracted from the data sources 
    /// (i.e. Radon Retrievals) whenever the given Radon Request gets solved on the Witnet blockchain. 
    /// @dev Reverts if unknown.
    function lookupRadonRequestRetrievalsAggregator(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonReducer memory);

    /// @notice Returns the number of data sources referred by the specified Radon Request.
    /// @dev Reverts if unknown.
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

    /// @notice Verifies and registers on-chain the specified data source. 
    /// Returns a hash value that uniquely identifies the verified Data Source (aka. Radon Retrieval).
    /// All parameters but the request method are parameterizable by using embedded wildcard \x\ substrings (with x='0'..'9').
    /// @dev Reverts if:
    /// - unsupported request method is given;
    /// - no URL is provided in HTTP/* requests;
    /// - non-empty strings given on WIT/RNG requests.
    function verifyDataSource(Witnet.DataSource calldata dataSource) external returns (bytes32);

    /// @notice Verifies and registers the given sequence of dataset filters and reducing function to be 
    /// potentially used as either Aggregate or Tally reducers within the resolution workflow
    /// of Radon Requests in the Wit/Oracle blockchain. Returns a hash value that uniquely identifies the 
    /// given Radon Reducer in the registry. 
    /// @dev Reverts if unsupported reducing or filtering methods are specified.
    function verifyRadonReducer(Witnet.RadonReducer calldata reducer) external returns (bytes32);

    /// @notice Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals)
    /// and the aggregate and tally Radon Reducers. Returns a unique RAD hash that identifies the 
    /// verified Radon Request. 
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - any of passed retrievals is parameterized;
    /// - unsupported reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
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
            bytes32[] calldata dataSources,
            bytes32 dataSourcesAggregator,
            bytes32 crowdAttestationTally
        ) external returns (Witnet.RadonHash radonRequestHash);

    /// @notice Verifies and registers a new Radon Request out of some parametrized Radon Retrieval (i.e. data source).
    /// The Radon Request will replicate the Radon Retrieval as many times as the number of provided `modalUrls`, using
    /// the provided `modalArgs` to fulfill template parameters, and the specified aggretate and tally Radon Reducers.
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// - unverified retrieval is passed;
    /// - ranks of passed args don't match with those expected by given retrieval, after replacing the data provider URL.
    /// - unverified reducers are passed.
    function verifyRadonModalRequest(
            bytes32 modalRetrieval,
            string[] calldata modalArgs,
            string[] calldata modalUrls,
            bytes32 dataSourcesAggregatorHash,
            bytes32 crowdAttestationTallyHash
        ) external returns (Witnet.RadonHash radonRequestHash);

    /// @notice Verifies and registers the specified Radon Request out of some parameterized Radon Retrieval (i.e. data source), 
    /// the provided template parameters and the specified aggregate and tally Radon Reducers. 
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - ranks of passed args don't match with those required by each given retrieval;
    /// - unsupported reducers are passed.
    function verifyRadonTemplateRequest(
            bytes32[] calldata  templateRetrievals,
            string[][] calldata templateArgs,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        ) external returns (Witnet.RadonHash radonRequestHash);

    /// @notice Verifies and registers a new Radon Request out of some parameterized Radon Retrieval (i.e. data source), 
    /// the provided template parameters and the specified aggregate and tally Radon Reducers. 
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrieval is passed;
    /// - ranks of passed args don't match with those expected by given retrieval, after replacing the data provider URL.
    /// - unverified reducers are passed.
    function verifyRadonTemplateRequest(
            bytes32[] calldata  templateRetrievals,
            string[][] calldata templateArgs,
            bytes32 dataSourcesAggregatorHash,
            bytes32 crowdAttestationTallyHash
        ) external returns (Witnet.RadonHash radonRequestHash);
}