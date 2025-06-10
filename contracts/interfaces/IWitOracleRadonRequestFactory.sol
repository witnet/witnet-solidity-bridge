// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleRadonRequestModal.sol";
import "./IWitOracleRadonRequestTemplate.sol";

interface IWitOracleRadonRequestFactory {

    event NewRadonRequestModal(address witOracleRadonRequestModal);
    event NewRadonRequestTemplate(address witOracleRadonRequestTemplate);

    struct DataSource {
        string url;
        DataSourceRequest request;
    }

    struct DataSourceRequest {
        Witnet.RadonRetrievalMethods method;
        string body;
        string[2][] headers;
        bytes script;
    }

    function buildRadonRequestModal(
            DataSourceRequest calldata commonDataRequest,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (IWitOracleRadonRequestModal);

    function buildRadonRequestTemplate(
            bytes32[] calldata dataRetrieveHashes,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        ) external returns (IWitOracleRadonRequestTemplate);
        
    function buildRadonRequestTemplate(
            DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        external returns (IWitOracleRadonRequestTemplate);
}
