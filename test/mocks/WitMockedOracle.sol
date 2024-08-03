// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedRadonRegistry.sol";
import "./WitMockedRequestFactory.sol";
import "../../contracts/core/trustable/WitnetOracleTrustableDefault.sol";

import "./WitMockedPriceFeeds.sol";
import "./WitMockedRandomness.sol";

/// @title Mocked implementation of `WitnetOracle`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetOracle` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedOracle
    is
        WitnetOracleTrustableDefault
{
    constructor(WitMockedRadonRegistry _registry) 
        WitnetOracleTrustableDefault(
            WitnetRadonRegistry(_registry),
            WitnetRequestFactory(address(0)), 
            false,
            bytes32("mocked"),
            60000, 65000, 70000, 20000
        )
    {
        address[] memory _reporters = new address[](1);
        _reporters[0] = msg.sender;
        __setReporters(_reporters);
    }
} 
