// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPythErrors.sol";
import "./IWitPythEvents.sol";

import "../../libs/Witnet.sol";

interface IWitPyth
    is
        IWitPythErrors,
        IWitPythEvents
{
    type ID is bytes32;

    struct Price {
        /// Price value asked for: either as provided by the Wit/Oracle,
        /// or the on-chain computed exponentially-weighted moving average (if available).
        uint64 price;
        
        /// Current market per-thousand deviation with respect to last known non-deviated price update. 
        uint64 conf;
        
        /// Base-10 exponent for converting `price` into the actual market float price. 
        int32  expo;
        
        /// Unix timestamp of when the last known price was solved on the Wit/Oracle blockchain. 
        Witnet.Timestamp publishTime;
        
        /// After-the-fact data source traceability proof in the Wit/Oracle blockchain for last known update. 
        Witnet.TransactionHash track;
    }

    struct PriceFeed {
        ID id;
        Price price;
        Price emaPrice;
    }

    /// @notice Returns the exponentially-weighted moving average price.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Price Feed ID of which to fetch the EMA price.
    function getEmaPrice(ID id) external view returns (Price memory);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    function getEmaPriceNotOlderThan(ID id, uint64 age) external view returns (Price memory);

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    function getEmaPriceUnsafe(ID id) external view returns (Price memory);

    // /// @notice Returns the latest known exponentially-weight average price for all required price feeds 
    // /// without any sanity checks. This function is unsafe as the returned price updates may be arbitrarily 
    // /// far in the past.
    // /// 
    // /// Users of this function should check the `timestamp` of each price feed to ensure that the returned values 
    // /// are sufficiently recent for their application. If you need safe access to fresh data, please consider
    // /// using calling to either `getEmaPrice` or `getEmaPriceNoOlderThan` for every individual price feed.
    // function getEmaPricesUnsafe(ID[] calldata ids) external view returns (Price[] memory);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `heartbeatSecs`. 
    /// @param id The Price Feed ID of which to fetch the price.
    function getPrice(ID id) external view returns (Price memory);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. 
    /// Reverts if the price wasn't updated sufficiently
    /// recently.
    function getPriceNotOlderThan(ID id, uint64 age) external view returns (Price memory);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    /// 
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    function getPriceUnsafe(ID id) external view returns (Price memory);

    // /// @notice Returns the latest known update for all required price feeds without any sanity checks.
    // /// This function is unsafe as the returned price updates may be arbitrarily far in the past.
    // /// 
    // /// Users of this function should check the `timestamp` of each price feed to ensure that the returned values 
    // /// are sufficiently recent for their application. If you need safe access to fresh data, please consider
    // /// using calling to either `getPrice` or `getPriceNoOlderThan` for every individual price feed.
    // function getPriceFeedsLastUpdate(ID[] calldata ids) external view returns (Price[] memory);
    
    /// @notice Legacy-compliant to get the required fee to update an array of price updates, which would be
    /// always 0 if relying on the Wit/Oracle bridging framework. 
    function getUpdateFee(bytes calldata) external view returns (uint256);
    
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
            ID[] calldata ids, 
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
            ID[] calldata ids, 
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
            ID[] calldata ids, 
            Witnet.Timestamp[] calldata timestamps
        ) external;
}
