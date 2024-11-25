// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitFeeds.sol";
import "./interfaces/IWitPriceFeeds.sol";

/// @title WitPriceFeeds: Price Feeds live repository reliant on the Wit/Oracle blockchain.
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

    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitOracleAppliance).interfaceId
                ^ type(IERC2362).interfaceId
                ^ type(IWitFeeds).interfaceId
                ^ type(IWitPriceFeeds).interfaceId
        );
    }
}
