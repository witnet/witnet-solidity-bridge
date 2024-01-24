// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestTemplate.sol";

abstract contract WitnetRequest
    is
        WitnetRequestTemplate
{
    /// introspection methods
    function template() virtual external view returns (WitnetRequestTemplate);

    /// request-exclusive fields
    function args() virtual external view returns (string[][] memory);
    function bytecode() virtual external view returns (bytes memory);
    function radHash() virtual external view returns (bytes32);
}