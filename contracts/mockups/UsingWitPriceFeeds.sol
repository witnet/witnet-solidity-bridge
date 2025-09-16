// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitPriceFeeds.sol";

/// @title The UsingWitPriceFeeds contract
/// @dev Contracts willing to interact with a WitPriceFeeds appliance, freshly updated by a third-party.
/// @author The Witnet Foundation.
abstract contract UsingWitPriceFeeds {
    IWitPriceFeeds immutable public WIT_PRICE_FEEDS;
    
    constructor(address _witPriceFeeds) {
        require(
            _witPriceFeeds.code.length > 0
                && IWitAppliance(_witPriceFeeds).specs() == type(IWitPriceFeeds).interfaceId,
            "uncompliant wit/price feeds appliance"
        );
        WIT_PRICE_FEEDS = IWitPriceFeeds(_witPriceFeeds);
    }
}
