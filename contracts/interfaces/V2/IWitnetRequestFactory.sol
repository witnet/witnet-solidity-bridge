// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../../WitnetBytecodes.sol";

interface IWitnetRequestFactory {
    event WitnetRequestTemplateBuilt(address template, bool parameterized);
    function buildRequestTemplate(
            bytes32[] memory sourcesIds,
            bytes32 aggregatorId,
            bytes32 tallyId,
            uint16  resultDataMaxSize
        ) external returns (address template);
    function class() external view returns (bytes4);    
    function registry() external view returns (WitnetBytecodes);
}