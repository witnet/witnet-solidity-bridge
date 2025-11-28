// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleRadonRequestModal.sol";
import "./IWitOracleRadonRequestTemplate.sol";

interface IWitOracleRadonRequestFactory {

    event NewRadonRequestModal(address witOracleRadonRequestModal);
    event NewRadonRequestTemplate(address witOracleRadonRequestTemplate);

    /// @notice Build a new single-source Radon Request based on the specified Data Source,
    /// and the crowd-attestation Radon Reducer.
    /// @dev Reverts if an unsupported Radon Reducer is passed.
    function buildRadonRequest(
            Witnet.DataSource calldata dataSource,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (Witnet.RadonHash);

    /// @notice Build a new multi-source Radon Request, based on the specified Data Sources,
    /// and the passed source-aggregation and crowd-attestation Radon Reducers. 
    /// @dev Reverts if unsupported Radon Reducers are passed.
    function buildRadonRequest(
            Witnet.DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (Witnet.RadonHash);

    /// @notice Build a new Radon Modal request factory, based on the specified Data Source Request,
    /// and the passed crowd-attestation Radon Reducer.
    /// @dev Reverts if the Data Source Request is not parameterized, or
    /// if an unsupported Radon Reducer is passed.
    function buildRadonRequestModal(
            Witnet.DataSourceRequest calldata modalRequest,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (IWitOracleRadonRequestModal);

    /// @notice Build a new Radon Template request factory, based on pre-registered Data Sources,
    /// and the passed source-aggregation and crowd-attestation Radon Reducers.
    /// @dev Reverts if:
    ///      - data-incompatible data sources are passed
    ///      - none of data sources is parameterized
    ///      - unsupported source-aggregation reducer is passed
    ///      - unsupported crowd-attesation reducer is passed
    function buildRadonRequestTemplate(
            bytes32[] calldata dataRetrieveHashes,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        ) external returns (IWitOracleRadonRequestTemplate);
        
    /// @notice Build a new Radon Template request factory, based on the specified Data Sources,
    /// and the passed source-aggregation and crowd-attestation Radon Reducers.
    /// @dev Reverts if:
    ///      - data-incompatible data sources are passed
    ///      - none of data sources is parameterized
    ///      - unsupported source-aggregation reducer is passed
    ///      - unsupported crowd-attesation reducer is passed
    function buildRadonRequestTemplate(
            Witnet.DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (IWitOracleRadonRequestTemplate);

    /// @notice Registers on-chain the specified Data Source/s. 
    /// Returns a hash value that uniquely identifies the verified Data Source (aka. Radon Retrieval).
    /// All parameters but the request method are parameterizable by using embedded wildcard `\x\` substrings (with `x = 0..9`).
    /// @dev Reverts if:
    /// - unsupported request method is given;
    /// - no URL is provided in HTTP/* requests;
    /// - non-empty strings given on WIT/RNG requests.
    function registerDataSource(Witnet.DataSource calldata dataSource) external returns (bytes32);
    function registerDataSources(Witnet.DataSource[] calldata dataSources) external returns (bytes32[] memory);
}
