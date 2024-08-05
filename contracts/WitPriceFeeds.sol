// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitFeeds.sol";
import "./interfaces/IWitPriceFeeds.sol";

/// @title WitPriceFeeds: Price Feeds live repository reliant on the Witnet Oracle blockchain.
/// @author The Witnet Foundation.
abstract contract WitPriceFeeds
    is
        WitFeeds,
        IWitPriceFeeds
{
    constructor()
        WitFeeds(
            Witnet.RadonDataTypes.Integer,
            "Price-"
        ) 
    {}
}
