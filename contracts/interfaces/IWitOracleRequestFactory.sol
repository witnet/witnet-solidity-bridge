// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./IWitOracleRequestTemplate.sol";

interface IWitOracleRequestFactory {
    
    /// @notice Builds a WitOracleRequest instance that will provide the bytecode
    /// @notice and RAD hash of some Witnet-compliant data request, provably 
    /// @notice made out of some previously verified Witnet Radon Retrievals
    /// @notice (i.e. data sources), aggregate and tally Witnet Radon Reducers.
    /// @dev Reverts if:
    /// @dev   - unverified retrievals are passed;
    /// @dev   - any of the given retrievals is parameterized;
    /// @dev   - retrievals return different data types;
    /// @dev   - unsupported reducers are passed.
    /// @param retrieveHashes Hashes of previously verified data sources.
    /// @param aggregate The Radon Reducer to apply on values returned from data sources.
    /// @param tally The Radon Reducer to apply on values revealed by witnessing nodes.
    function buildWitOracleRequest(
            bytes32[] calldata retrieveHashes,
            Witnet.RadonReducer calldata aggregate,
            Witnet.RadonReducer calldata tally
        ) external returns (IWitOracleRequest);

    /// @notice Builds a modal WitOracleRequest instance out of one single parameterized 
    /// @notice Witnet Radon Retrieval. Modal data requests apply the same data retrieval script
    /// @notice to multiple data providers that are expected to produce exactly the same result. 
    /// @notice Moreover, modal data requests apply a Mode reducing function at both the 
    /// @notice Aggregate and Tally stages everytime they get eventually solved on the Wit/Oracle
    /// @notice blockhain. You can optionally specify a list of filters to be applied at the Tally 
    /// @notice resolution stage (i.e. witnessing nodes on the Wit/Oracle blockchain reporting results
    /// @notice that get ultimately filtered out on the Tally stage would get slashed by losing collateral).
    /// @dev Reverts if:
    /// @dev  - unverified base Radon Retrieval is passed;
    /// @dev  - the specified base Radon Retrieval is not parameterized;
    /// @dev  - 2nd dimension's rank of the `requestArgs` array doesn't match the number of required parameters 
    /// @dev    required by the given Radon Retrieval;
    /// @dev  - unsupported Radon Filters are passed.
    /// @param baseRetrieveHash Hash of the parameterized Radon Retrieval upon which the new data request will be built.
    /// @param requestArgs Parameters to be applied to each repetition of the given retrieval.
    /// @param tallySlashingFilters Optional array of slashing filters to will be applied at the Tally stage.
    function buildWitOracleRequestModal(
            bytes32 baseRetrieveHash,
            string[][] calldata requestArgs,
            Witnet.RadonFilter[] calldata tallySlashingFilters
        ) external returns (IWitOracleRequest);

    /// @notice Builds a WitOracleRequestTemplate instance made out of one or more
    /// @notice parameterized Witnet Radon Retrievals (i.e. data sources), aggregate
    /// @notice and tally Witnet Radon Reducers. 
    /// @dev Reverts if:
    /// @dev   - unverified retrievals are passed;
    /// @dev   - none of given retrievals is parameterized;
    /// @dev   - retrievals return different data types;
    /// @dev   - unsupported reducers are passed.
    /// @param retrieveHashes Hashes of previously verified data sources.
    /// @param aggregate The Radon Reducer to apply on values returned from data sources.
    /// @param tally The Radon Reducer to apply on values revealed by witnessing nodes.
    function buildWitOracleRequestTemplate(
            bytes32[]  calldata retrieveHashes,
            Witnet.RadonReducer calldata aggregate,
            Witnet.RadonReducer calldata tally
        ) external returns (IWitOracleRequestTemplate);

    /// @notice Builds a modal WitOracleRequestTemplate instance out of one single parameterized 
    /// @notice Witnet Radon Retrieval. Modal request templates produce Witnet-compliant data requests
    /// @notice that apply the same data retrieval script to multiple data providers that are expected to
    /// @notice produce exactly the same result. Moreover, data requests built out of a modal request templates
    /// @notice apply a Mode reducing function at both the Aggregate and Tally stages everytime they get
    /// @notice eventually solved on the Wit/Oracle blockchain. You can optionally specify a list of filters 
    /// @notice to be applied at the Tally resolution stage (i.e. witnessing nodes on the Wit/Oracle blockchain
    /// @notice reporting results that get ultimately filtred out on the Tally stage would get slashed by losing collateral).
    /// @dev Reverts if:
    /// @dev  - unverified base Radon Retrieval is passed;
    /// @dev  - the specified base Radon Retrieval is either not parameterized or requires just one single parameter;
    /// @dev  - unsupported Radon Filters are passed.
    /// @param baseRetrieveHash Hash of the parameterized Radon Retrieval upon which the new data request will be built.
    /// @param lastArgValues Parameters to be applied to each repetition of the given retrieval.
    /// @param tallySlashingFilters Optional array of slashing filters to will be applied at the Tally stage.
    function buildWitOracleRequestTemplateModal(
            bytes32 baseRetrieveHash,
            string[] calldata lastArgValues,
            Witnet.RadonFilter[] calldata tallySlashingFilters
        ) external returns (IWitOracleRequestTemplate);

    /// @notice Verifies and registers the specified Witnet Radon Retrieval 
    /// @notice (i.e. public data sources) into the WitOracleRadonRegistry of the
    /// @notice WitOracle attached to this factory. Returns a hash that uniquely 
    /// @notice identifies validated data source within the WitOracleRadonRegistry.
    /// @dev Note: all input parameters but the `requestMethod` are parameterizable
    /// @dev       by using embedded wildcard `\x\` substrings (being `x='0'..'9').
    /// @dev Reverts if:
    /// @dev   - unsupported data request method is given;
    /// @dev   - no URL is provided on Http/* data requests;
    /// @dev   - non-empty strings given on RNG data requests..
    function verifyRadonRetrieval(
            Witnet.RadonRetrievalMethods requestMethod,
            string calldata requestURL,
            string calldata requestBody,
            string[2][] calldata requestHeaders,
            bytes calldata requestRadonScript
        ) external returns (bytes32 retrievalHash);
}
