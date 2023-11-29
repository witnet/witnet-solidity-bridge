// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../apps/WitnetPriceFeeds.sol";

contract WitnetPriceFeedsMock is WitnetPriceFeeds {
    constructor(WitnetRequestBoard _wrb)
        WitnetPriceFeeds(
            msg.sender,
            _wrb
        )
    {}
}
