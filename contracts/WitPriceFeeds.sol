// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitFeeds.sol";

import "./interfaces/IWitPriceFeeds.sol";
import "./interfaces/IWitPriceFeedsSolverFactory.sol";

/// @title WitPriceFeeds: Price Feeds live repository reliant on the Wit/Oracle blockchain.
/// @author The Witnet Foundation.
abstract contract WitPriceFeeds
    is
        WitFeeds,
        IWitPriceFeeds,
        IWitPriceFeedsSolverFactory
{
    constructor()
        WitFeeds(
            Witnet.RadonDataTypes.Integer,
            "Price-"
        ) 
    {}

    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IERC2362).interfaceId
                ^ type(IWitOracleAppliance).interfaceId
                ^ type(IWitFeeds).interfaceId
                ^ type(IWitFeedsAdmin).interfaceId
                ^ type(IWitPriceFeeds).interfaceId
                ^ type(IWitPriceFeedsSolverFactory).interfaceId
        );
    }
}
