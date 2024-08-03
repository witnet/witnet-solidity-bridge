// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedOracle.sol";
import "../../contracts/apps/WitPriceFeedsV21.sol";

/// @title Mocked implementation of `WitnetPriceFeeds`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetPriceFeeds` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedPriceFeeds is WitPriceFeedsV21 {
    constructor(WitMockedOracle _wrb)
        WitPriceFeedsV21(
            _wrb,
            false,
            bytes32("mocked")
        )
    {}
}
