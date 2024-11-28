// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedRadonRegistry.sol";
import "./WitMockedRequestFactory.sol";
import "../../core/trustable/WitOracleTrustableDefault.sol";

import "./WitMockedPriceFeeds.sol";
import "./WitMockedRandomness.sol";

/// @title Mocked implementation of `WitOracle`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitOracle` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedOracle
    is
        WitOracleTrustableDefault
{
    constructor(WitMockedRadonRegistry _registry) 
        WitOracleTrustableDefault(
            EvmImmutables(60000, 65000, 70000, 20000),
            WitOracleRadonRegistry(_registry),
            bytes32("mocked")
        )
    {
        address[] memory _reporters = new address[](1);
        _reporters[0] = msg.sender;
        WitOracleDataLib.setReporters(_reporters);
    }
} 
