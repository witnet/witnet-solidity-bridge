// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../core/defaults/WitnetBytecodesDefault.sol";

contract WitnetMockedBytecodes is WitnetBytecodesDefault {
    constructor()
        WitnetBytecodesDefault(
            false,
            bytes32("mocked")
        )
    {}
}
