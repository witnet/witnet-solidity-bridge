// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitPriceFeeds.sol";

/// @title The UsingWitPriceFeeds contract
/// @dev Contracts willing to interact with a WitPriceFeeds appliance, freshly updated by a third-party.
/// @author The Witnet Foundation.
abstract contract UsingWitPriceFeeds
    is
        IWitFeedsEvents,
        IWitOracleEvents
{
    WitPriceFeeds immutable public witPriceFeeds;

    constructor(WitPriceFeeds _witPriceFeeds) {
        require(
            address(_witPriceFeeds).code.length > 0
                && _witPriceFeeds.specs() == type(WitPriceFeeds).interfaceId,
            "UsingWitPriceFeeds: uncompliant WitPriceFeeds appliance"
        );
        witPriceFeeds = _witPriceFeeds;
    }

    receive() external payable virtual {}
}
