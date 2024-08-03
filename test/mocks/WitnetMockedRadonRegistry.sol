// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../contracts/core/defaults/WitnetRadonRegistryDefault.sol";

/// @title Mocked implementation of `WitnetRadonRegistry`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetRadonRegistry` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedRadonRegistry is WitnetRadonRegistryDefault {
    constructor()
        WitnetRadonRegistryDefault(
            false,
            bytes32("mocked")
        )
    {}
}
