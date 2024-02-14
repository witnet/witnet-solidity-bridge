// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../core/defaults/WitnetRequestBytecodesDefault.sol";

/// @title Mocked implementation of `WitnetRequestBytecodes`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetRequestBytecodes` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedRequestBytecodes is WitnetRequestBytecodesDefault {
    constructor()
        WitnetRequestBytecodesDefault(
            false,
            bytes32("mocked")
        )
    {}
}
