// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetBytecodes.sol";
import "../WitnetRequestFactory.sol";

abstract contract WitnetRequestTemplate
{
    event WitnetRequestBuilt(address indexed request, bytes32 indexed radHash, string[][] args);

    function class() virtual external view returns (bytes4);
    function factory() virtual external view returns (WitnetRequestFactory);
    function registry() virtual external view returns (WitnetBytecodes);
    function version() virtual external view returns (string memory);

    function aggregator() virtual external view returns (bytes32);
    function parameterized() virtual external view returns (bool);
    function resultDataMaxSize() virtual external view returns (uint16);
    function resultDataType() virtual external view returns (WitnetV2.RadonDataTypes);
    function retrievals() virtual external view returns (bytes32[] memory);
    function tally() virtual external view returns (bytes32);
    
    function getRadonAggregator() virtual external view returns (WitnetV2.RadonReducer memory);
    function getRadonRetrievalByIndex(uint256) virtual external view returns (WitnetV2.RadonRetrieval memory);
    function getRadonRetrievalsCount() virtual external view returns (uint256);
    function getRadonTally() virtual external view returns (WitnetV2.RadonReducer memory);
    
    function buildRequest(string[][] calldata args) virtual external returns (address);
    function verifyRadonRequest(string[][] calldata args) virtual external returns (bytes32);
}

abstract contract WitnetRequest
    is
        WitnetRequestTemplate
{
    event WitnetRequestSettled(IWitnetRequest indexed request, bytes32 radHash, bytes32 slaHash);

    /// introspection methods
    function template() virtual external view returns (WitnetRequestTemplate);

    /// request-exclusive fields
    function args() virtual external view returns (string[][] memory);
    function bytecode() virtual external view returns (bytes memory);
    function radHash() virtual external view returns (bytes32);
}