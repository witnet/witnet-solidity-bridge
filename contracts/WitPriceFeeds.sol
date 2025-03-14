// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "ado-contracts/contracts/interfaces/IERC2362.sol";
import "./interfaces/IWitOracle.sol";
import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleRadonRegistry.sol";
import "./interfaces/IWitPriceFeeds.sol";

/// @title WitPriceFeeds: Price Feeds repository powered by the Wit/Oracle, 
/// @title and yet usable from both Chainlink and Pyth clients.
/// @author The Witnet Foundation.
abstract contract WitPriceFeeds
    is
        IERC2362,
        IWitAppliance,
        IWitPriceFeeds
{
    IWitOracle immutable public witOracle;
    IWitOracleRadonRegistry immutable public witOracleRadonRegistry;

    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IERC2362).interfaceId
                ^ type(IWitPriceFeeds).interfaceId
                ^ type(IWitOracleAppliance).interfaceId
        );
    }
}
