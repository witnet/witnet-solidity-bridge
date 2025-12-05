// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitPriceFeeds.sol";

/// @title The UsingWitPriceFeeds contract.
/// @author The Witnet Foundation.
abstract contract UsingWitPriceFeeds
    is
        IWitPriceFeedsEvents,
        IWitPriceFeedsTypes
{
    WitPriceFeeds immutable internal __witPriceFeeds;
    
    constructor(IWitPriceFeeds router) {
        require(
            address(router) != address(0)
                && address(router).code.length > 0
                && WitPriceFeeds(address(router)).specs() == type(IWitPriceFeeds).interfaceId,
            "UsingWitPriceFeeds: uncompliant WitPriceFeeds"
        );
        __witPriceFeeds = WitPriceFeeds(address(router));
    }

    /// @notice Reference to the underlying Wit/Oracle Framework.
    function witOracle() virtual public view returns (address) {
        return __witPriceFeeds.witOracle();
    }
}
