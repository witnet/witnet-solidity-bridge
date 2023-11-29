// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetMockedRequestBoard.sol";
import "../core/defaults/WitnetRequestFactoryDefault.sol";

contract WitnetMockedRequestFactory
    is 
        WitnetRequestFactoryDefault
{
    constructor (WitnetMockedRequestBoard _wrb)
        WitnetRequestFactoryDefault(
            WitnetRequestBoard(address(_wrb)),
            WitnetBytecodes(_wrb.registry()),
            false,
            bytes32("mocked")
        ) 
    {}
}