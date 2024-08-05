// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedOracle.sol";
import "../../contracts/core/trustless/WitOracleRequestFactoryDefault.sol";

/// @title Mocked implementation of `WitOracleRequestFactory`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitOracleRequestFactory` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedRequestFactory
    is 
        WitOracleRequestFactoryDefault
{
    constructor (WitMockedOracle _witOracle)
        WitOracleRequestFactoryDefault(
            WitOracle(address(_witOracle)),
            false,
            bytes32("mocked")
        ) 
    {}
}