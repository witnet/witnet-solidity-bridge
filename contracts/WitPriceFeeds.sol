// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "ado-contracts/contracts/interfaces/IERC2362.sol";

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleConsumer.sol";
import "./interfaces/IWitPriceFeeds.sol";
import "./interfaces/IWitPriceFeedsAdmin.sol";

/// @title WitPriceFeeds: Price Feeds repository powered by the Wit/Oracle, 
/// @title and yet usable from both Chainlink and Pyth clients.
/// @author The Witnet Foundation.
abstract contract WitPriceFeeds
    is
        IERC2362,
        IWitOracleAppliance,
        IWitOracleConsumer,
        IWitPriceFeeds,
        IWitPriceFeedsAdmin,
        IWitPyth
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitPriceFeeds).interfaceId
                ^ type(IWitPriceFeedsAdmin).interfaceId
        );
    }
}
