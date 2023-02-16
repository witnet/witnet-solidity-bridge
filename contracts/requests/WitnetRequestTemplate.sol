// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../libs/WitnetV2.sol";


abstract contract WitnetRequestTemplate
    is
        IWitnetRequest
{
    event WitnetRequestTemplateSettled(WitnetRequest indexed request, bytes32 indexed radHash, string[][] args);

    function getDataSources() virtual external view returns (bytes32[] memory);
    function getDataSourcesArgsCount() virtual external view returns (uint8[] memory);
    function getDataSourcesCount() virtual external view returns (uint256);    
    function getRadonAggregatorHash() virtual external view returns (bytes32);
    function getRadonTallyHash() virtual external view returns (bytes32);
    function getResultDataMaxSize() virtual external view returns (uint16);
    function getResultDataType() virtual external view returns (WitnetV2.RadonDataTypes);
    function lookupDataSourceByIndex(uint256) virtual external view returns (WitnetV2.DataSource memory);
    function lookupRadonAggregator() virtual external view returns (WitnetV2.RadonReducer memory);
    function lookupRadonTally() virtual external view returns (WitnetV2.RadonReducer memory);
    function settleArgs(string[][] calldata args) virtual external returns (WitnetRequest);
}