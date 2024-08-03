// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetMockedOracle.sol";
import "../../contracts/apps/WitnetPriceFeedsV21.sol";

/// @title Mocked implementation of `WitnetPriceFeeds`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetPriceFeeds` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedPriceFeeds is WitnetPriceFeedsV21 {
    constructor(WitnetMockedOracle _wrb)
        WitnetPriceFeedsV21(
            _wrb,
            false,
            bytes32("mocked")
        )
    {}
}
