// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IWitnetRequest.sol";
import "../interfaces/V2/IWitnetRequestFactory.sol";
import "../libs/WitnetV2.sol";

abstract contract WitnetRequestTemplate
{
    event WitnetRequestBuilt(WitnetRequest indexed request, bytes32 indexed radHash, string[][] args);

    function class() virtual external view returns (bytes4);
    function factory() virtual external view returns (IWitnetRequestFactory);
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
    
    function buildRequest(string[][] calldata args) virtual external returns (WitnetRequest);
    function verifyRadonRequest(string[][] calldata args) virtual external returns (bytes32);
}

abstract contract WitnetRequest
    is
        IWitnetRequest,
        WitnetRequestTemplate
{
    event WitnetRequestSettled(IWitnetRequest indexed request, bytes32 radHash, bytes32 slaHash);

    /// introspection methods
    function curator() virtual external view returns (address);
    function secured() virtual external view returns (bool);
    function template() virtual external view returns (WitnetRequestTemplate);

    /// request-exclusive fields
    function args() virtual external view returns (string[][] memory);
    function radHash() virtual external view returns (bytes32);
    function slaHash() virtual external view returns (bytes32);

    /// @notice Get request's Radon SLA as verified into the factory's registry.
    function getRadonSLA() virtual external view returns (WitnetV2.RadonSLA memory);
    
    /// @notice Settle request's SLA. Returns address(this) if called from request's curator.
    /// @notice Otherwise, returns deterministic IWitnetRequest address based on:
    /// @notice - address(this);
    /// @notice - hash of provided SLA;
    /// @notice - factory's major/mid version.
    /// @dev Returned instance will match address(this) only if called from request's curator. 
    /// @dev Curator of returned instance may be different than caller's address.
    function settleRadonSLA(WitnetV2.RadonSLA calldata sla) virtual external returns (WitnetRequest);
}