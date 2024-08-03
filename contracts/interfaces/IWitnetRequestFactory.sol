// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetRequestFactory {
    
    /// @notice Builds a Witnet Request instance that will provide the bytecode
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
    function buildWitnetRequest(
            bytes32[] calldata retrieveHashes,
            Witnet.RadonReducer calldata aggregate,
            Witnet.RadonReducer calldata tally
        ) external returns (address request);

    /// @notice Builds a Witnet Request Template instance made out of one or more
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
    function buildWitnetRequestTemplate(
            bytes32[]  calldata retrieveHashes,
            Witnet.RadonReducer calldata aggregate,
            Witnet.RadonReducer calldata tally
        ) external returns (address template);

    /// @notice Verifies and registers the specified Witnet Radon Retrieval 
    /// @notice (i.e. public data sources) into the WitnetRadonRegistry of the
    /// @notice WitnetOracle attached to this factory. Returns a hash that uniquely 
    /// @notice identifies validated data source within the WitnetRadonRegistry.
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
