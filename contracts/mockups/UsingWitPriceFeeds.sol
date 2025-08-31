// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitPriceFeeds.sol";

/// @title The UsingWitPriceFeeds contract
/// @dev Contracts willing to interact with a WitPriceFeeds appliance, freshly updated by a third-party.
/// @author The Witnet Foundation.
abstract contract UsingWitPriceFeeds
    is
        IWitPythEvents
{
    IWitPriceFeeds immutable public WIT_PRICE_FEEDS;
    constructor(IWitPriceFeeds _witPriceFeeds) {
        require(
            address(_witPriceFeeds).code.length > 0
                && IWitAppliance(address(_witPriceFeeds)).specs() == type(IWitPriceFeeds).interfaceId,
            "UsingWitPriceFeeds: uncompliant appliance"
        );
        WIT_PRICE_FEEDS = _witPriceFeeds;
    }
}
