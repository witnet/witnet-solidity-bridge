// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./apps/WitnetFeeds.sol";

import "./interfaces/V2/IWitnetPriceFeeds.sol";
import "./interfaces/V2/IWitnetPriceSolverDeployer.sol";

/// @title WitnetPriceFeeds: Price Feeds live repository reliant on the Witnet Oracle blockchain.
/// @author The Witnet Foundation.
abstract contract WitnetPriceFeeds
    is
        WitnetFeeds,
        IWitnetPriceFeeds,
        IWitnetPriceSolverDeployer
{
    function class() override external pure returns (string memory) {
        return type(WitnetPriceFeeds).name;
    }

    constructor()
        WitnetFeeds(Witnet.RadonDataTypes.Integer, "Price-") 
    {}

}
