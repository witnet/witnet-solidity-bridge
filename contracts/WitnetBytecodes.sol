// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/V2/IWitnetBytecodes.sol";

abstract contract WitnetBytecodes
    is
        IWitnetBytecodes
{
    function class() virtual external view returns (bytes4);
}