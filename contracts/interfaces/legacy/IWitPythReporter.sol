// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPyth.sol";

interface IWitPythReporter {
    
    struct PriceFeed {
        IWitPyth.ID id;
        IWitPyth.PythPrice price;
        IWitPyth.PythPrice emaPrice;
    }

    /// @notice Parse `updates` and return price feeds of the given `ids` if they reported
    /// timestamps are within specified `minTimestamp` and `maxTimestamp`. Unlike `updatePriceFeeds`, 
    /// calling this function will NOT update the on-chain price. 
    ///
    /// Use this function if you just want to use reported updates as long as they refer
    /// a timestamp within the specified range, and not necessarily most recent updates in storage.  
    /// Otherwise, consider using `updatePriceFeeds` followed by any of `get*Price*` methods.
   
    /// If you need to make sure to get the earliest update after `minTimestamp` (ie. the one on-chain 
    /// or the one being parsed), consider using `parsePriceFeedUpdatesUnique` instead.
    /// 
    /// @dev Reverts if there is no update for any of the given `ids` within the given time range.
    /// @param updates Array of price update reports.
    /// @param ids Array of price ids.
    /// @param minTimestamp minimum acceptable publishTime for the given `ids`.
    /// @param maxTimestamp maximum acceptable publishTime for the given `ids`.
    /// @return priceFeeds Array of parsed Prices corresponding to the given `ids` (with the same order).
    function parsePriceFeedUpdates(
            bytes[] calldata updates, 
            IWitPyth.ID[] calldata ids, 
            Witnet.Timestamp minTimestamp,
            Witnet.Timestamp maxTimestamp
        ) external view returns (PriceFeed[] memory);

    /// @notice Similar to `parsePriceFeedUpdates` but ensures the returned prices correspond to
    /// the earliest update after `minTimestamp`. That is to say, if `prevTs < minTs <= ts <= maxTs`, 
    /// where `prevTs` is the timestamp of latest on-chain timestamp for each referred price-feed.
    /// This will guarantee no updates exist for the given `priceIds` earlier than the returned 
    /// updates and still in the given time range. 
    
    /// Use this function is you just want to use reported updates for a fixed time window and 
    /// not necessarily the most recent update on-chain. Otherwise, consider using
    /// `updatePriceFeeds` followed by any of the  `get*PriceNoOlderThan` variants.
    /// 
    /// @dev Reverts if there is no update for any of the given `ids` within the given time range and 
    /// uniqueness condition.
    /// @param updates Array of price update reports.
    /// @param ids Array of price ids.
    /// @param minTimestamp minimum acceptable publishTime for the given `ids`.
    /// @param maxTimestamp maximum acceptable publishTime for the given `ids`.
    /// @return priceFeeds Array of the Prices corresponding to the given `ids` (with the same order).
    function parsePriceFeedUpdatesUnique(
            bytes[] calldata updates, 
            IWitPyth.ID[] calldata ids, 
            Witnet.Timestamp minTimestamp,
            Witnet.Timestamp maxTimestamp
        ) external view returns (PriceFeed[] memory);

    /// @notice Update price feeds with given update reports. Prices will be updated if 
    /// they are more recent than the current stored prices. 
    /// The call will succeed even if the update is not the most recent.
    /// 
    /// @dev Reverts if any of the update reports is invalid.
    /// @param updates Array of price update reports.
    function updatePriceFeeds(bytes[] calldata updates) external;

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. 
    /// A price update is necessary if the current on-chain publishTime is older than the given timestamp. 
    /// It relies solely on the given `timestamps` for the price feeds and does not read the actual price update 
    /// publish time within `updates`.
    ///
    /// `ids` and `timestamps` are two arrays with the same size that correspond to sender's known timestamps
    /// of each Price Feed id when calling this method. If all of price feeds within `ids` have updated and have
    /// a newer or equal timestamp than the given timestamp, it will reject the transaction to save gas.
    /// Otherwise, it calls updatePriceFeeds method to update the prices.
    ///
    /// @dev Reverts also if any of the price update data is valid.
    /// @param updates Array of price update data.
    /// @param ids Array of price ids.
    /// @param timestamps Array of timestamps: `timestamps[i]` corresponds to known `timestamp` of `ids[i]`
    function updatePriceFeedsIfNecessary(
            bytes[] calldata updates, 
            IWitPyth.ID[] calldata ids, 
            Witnet.Timestamp[] calldata timestamps
        ) external;
}
