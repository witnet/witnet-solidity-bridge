// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRequestModal {

    function getCrowdAttestationTally() external view returns (Witnet.RadonReducer memory);
    function getDataResultType() external view returns (Witnet.RadonDataTypes); 
    function getDataSourcesAggregator() external view returns (Witnet.RadonReducer memory);
    function getDataSourcesArgsCount() external view returns (uint8);
    function getRadonModalRetrieval() external view returns (Witnet.RadonRetrieval memory);

    function verifyRadonRequest(string[] calldata commonRetrievalArgs, string[] calldata dataProviders) external returns (Witnet.RadonHash);
    function witOracle() external view returns (address);
}
