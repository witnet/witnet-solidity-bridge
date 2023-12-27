// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../apps/WitnetPriceFeeds.sol";

/// @title Mocked implementation of `WitnetPriceFeeds`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetPriceFeeds` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedPriceFeeds is WitnetPriceFeeds {
    constructor(WitnetRequestBoard _wrb)
        WitnetPriceFeeds(
            msg.sender,
            _wrb
        )
    {}
}
