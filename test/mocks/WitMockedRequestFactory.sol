// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedOracle.sol";
import "../../contracts/core/upgradable/WitOracleRequestFactoryUpgradableDefault.sol";

/// @title Mocked implementation of `WitOracleRequestFactory`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitOracleRequestFactory` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedRequestFactory
    is 
        WitOracleRequestFactoryUpgradableDefault
{
    constructor (WitMockedOracle _witOracle)
        WitOracleRequestFactoryUpgradableDefault(
            WitOracle(address(_witOracle)),
            bytes32("mocked"),
            false
        ) 
    {}
}