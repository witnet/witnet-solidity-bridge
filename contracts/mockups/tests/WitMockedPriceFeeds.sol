// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedOracle.sol";
import "../../apps/WitPriceFeedsUpgradable.sol";

/// @title Mocked implementation of `WitPriceFeeds`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitPriceFeeds` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedPriceFeeds is WitPriceFeedsUpgradable {
    constructor(WitMockedOracle _witOracle)
        WitPriceFeedsUpgradable(
            _witOracle,
            bytes32("mocked"),
            false
        )
    {}
}
