// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../core/upgradable/WitOracleRadonRegistryUpgradableDefault.sol";

/// @title Mocked implementation of `WitOracleRadonRegistry`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitOracleRadonRegistry` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedRadonRegistry is WitOracleRadonRegistryUpgradableDefault {
    constructor()
        WitOracleRadonRegistryUpgradableDefault(
            bytes32("mocked"),
            false
        )
    {}
}
