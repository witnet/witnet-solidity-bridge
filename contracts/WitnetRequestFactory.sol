// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBytecodes.sol";
import "./WitnetRequestBoard.sol";
import "./interfaces/V2/IWitnetRequestFactory.sol";

abstract contract WitnetRequestFactory
    is
        IWitnetRequestFactory
{
    function class() virtual external view returns (string memory);
    function registry() virtual external view returns (WitnetRequestBytecodes);
    function specs() virtual external view returns (bytes4);
    function witnet() virtual external view returns (WitnetRequestBoard);
}