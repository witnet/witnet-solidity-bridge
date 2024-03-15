// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetFeeds.sol";

import "./interfaces/IWitnetPriceFeeds.sol";
import "./interfaces/IWitnetPriceSolverDeployer.sol";

/// @title WitnetPriceFeeds: Price Feeds live repository reliant on the Witnet Oracle blockchain.
/// @author The Witnet Foundation.
abstract contract WitnetPriceFeeds
    is
        WitnetFeeds,
        IWitnetPriceFeeds,
        IWitnetPriceSolverDeployer
{
    constructor()
        WitnetFeeds(Witnet.RadonDataTypes.Integer, "Price-") 
    {}

}
