// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../contracts/core/trustless/WitOracleRadonRegistryBaseUpgradableDefault.sol";

/// @title Mocked implementation of `WitOracleRadonRegistry`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitOracleRadonRegistry` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedRadonRegistry is WitOracleRadonRegistryBaseUpgradableDefault {
    constructor()
        WitOracleRadonRegistryBaseUpgradableDefault(
            false,
            bytes32("mocked")
        )
    {}
}
