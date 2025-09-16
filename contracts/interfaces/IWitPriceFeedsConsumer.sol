// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWitPriceFeeds.sol";

interface IWitPriceFeedsConsumer {
    /// Reports a Witnet-verified price feed update.
    /// @dev It should revert if called from an address other than `router()`.
    function reportUpdate(
            IWitPriceFeeds.ID4 id4, 
            Witnet.Timestamp timestamp,
            Witnet.TransactionHash trail,
            uint64 price, 
            int56 deltaPrice,
            uint64 deltaSecs,
            int8 exponent
        ) external;

    /// Return the address of the Wit/Oracle address that provides
    /// verified data from the Witnet blockchain. 
    function witOracle() external view returns (address);

    /// Returns the address of the one and only `IWitPriceFeeds` 
    /// instance that can provide price feed updates.
    function witPriceFeeds() external view returns (address);
}
