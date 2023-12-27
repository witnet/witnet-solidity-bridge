// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetMockedRequestBoard.sol";
import "../core/defaults/WitnetRequestFactoryDefault.sol";

/// @title Mocked implementation of `WitnetRequestFactory`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetRequestFactory` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
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