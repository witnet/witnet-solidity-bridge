// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../core/defaults/WitnetBytecodesDefault.sol";

/// @title Mocked implementation of `WitnetBytecodes`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetBytecodes` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedBytecodes is WitnetBytecodesDefault {
    constructor()
        WitnetBytecodesDefault(
            false,
            bytes32("mocked")
        )
    {}
}
