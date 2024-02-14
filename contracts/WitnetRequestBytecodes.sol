// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/V2/IWitnetRequestBytecodes.sol";

abstract contract WitnetRequestBytecodes
    is
        IWitnetRequestBytecodes
{
    function class() virtual external view returns (string memory) {
        return type(WitnetRequestBytecodes).name;
    }   
    function specs() virtual external view returns (bytes4);
}