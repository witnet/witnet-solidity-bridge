// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IWitPriceFeeds} from "./IWitPriceFeeds.sol";
import {IWitPriceFeedsTypes} from "./IWitPriceFeedsTypes.sol";
import {Witnet} from "../libs/Witnet.sol";

interface IWitPriceFeedsConsumer {
    /// Reports a Witnet-verified price feed update.
    /// @dev It should revert if called from an address other than `witPriceFeeds()`.
    function reportUpdate(
            IWitPriceFeedsTypes.ID4 id4, 
            Witnet.Timestamp timestamp,
            Witnet.TransactionHash trail,
            uint64 price, 
            int56 deltaPrice,
            uint64 deltaSecs,
            int8 exponent
        ) external;

    /// Returns the address of the one and only `IWitPriceFeeds` 
    /// instance that can provide price feed updates.
    function witPriceFeeds() external view returns (IWitPriceFeeds);
}
