// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleRadonRequestModal.sol";
import "./IWitOracleRadonRequestTemplate.sol";

interface IWitOracleRadonRequestFactory {

    event NewRadonRequestModal(address witOracleRadonRequestModal);
    event NewRadonRequestTemplate(address witOracleRadonRequestTemplate);

    function buildRadonRequestModal(
            Witnet.DataSourceRequest calldata modalRequest,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (IWitOracleRadonRequestModal);

    function buildRadonRequestTemplate(
            bytes32[] calldata dataRetrieveHashes,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        ) external returns (IWitOracleRadonRequestTemplate);
        
    function buildRadonRequestTemplate(
            Witnet.DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (IWitOracleRadonRequestTemplate);

    /// @notice Verifies and registers on-chain the specified data source. 
    /// Returns a hash value that uniquely identifies the verified Data Source (aka. Radon Retrieval).
    /// All parameters but the request method are parameterizable by using embedded wildcard \x\ substrings (with x='0'..'9').
    /// @dev Reverts if:
    /// - unsupported request method is given;
    /// - no URL is provided in HTTP/* requests;
    /// - non-empty strings given on WIT/RNG requests.
    function verifyDataSource(Witnet.DataSource calldata dataSource) external returns (bytes32);
    function verifyDataSources(Witnet.DataSource[] calldata dataSources) external returns (bytes32[] memory);

    /// @notice Verifies a new single-source Radon Request, based on the specified Data Sources,
    /// as the crowd-attestation tally Radon Reducer.
    /// @dev Reverts if unsupported reducers or filters are passed.
    function verifyRadonRequest(
            Witnet.DataSource calldata dataSource,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (Witnet.RadonHash);

    /// @notice Verifies a new multi-source Radon Request, based on the specified Data Source
    /// and the specified aggregate and tally Radon Reducers. 
    /// @dev Reverts if unsupported reducers or filters are passed.    
    function verifyRadonRequest(
            Witnet.DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (Witnet.RadonHash);

    /// The Wit/Oracle core address accepted as source of entropy.
    function witOracle() external view returns (address);
}
