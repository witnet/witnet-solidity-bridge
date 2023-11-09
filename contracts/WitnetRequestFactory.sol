// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetBytecodes.sol";
import "./interfaces/V2/IWitnetRequestFactory.sol";

abstract contract WitnetRequestFactory
    is
        IWitnetRequestFactory
{
    function class() virtual external view returns (bytes4);
    function registry() virtual external view returns (WitnetBytecodes);
}