// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBoardMock.sol";
import "../core/defaults/WitnetRequestFactoryDefault.sol";

contract WitnetRequestFactoryMock
    is 
        WitnetRequestFactoryDefault
{
    constructor (WitnetRequestBoardMock _wrb)
        WitnetRequestFactoryDefault(
            WitnetRequestBoard(address(_wrb)),
            WitnetBytecodes(_wrb.registry()),
            false,
            bytes32("mocked")
        ) 
    {}
}