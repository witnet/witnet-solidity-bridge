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
    struct Price {
        uint8  decimals;
        uint64 emaPrice;
        uint64 price;
        Witnet.Timestamp timestamp;
        Confidence confidence;
    }

    struct Confidence {
        Witnet.RadonHash witDrRadonHash;
        Witnet.QuerySLA witDrRadonParams;
        Witnet.TransactionHash witDrTxHash;
    }

    /// @notice Returns the exponentially-weighted moving average price and confidence params.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Price Feed ID of which to fetch the EMA price and confidence params.
    function getEmaPrice(bytes32 id) external view returns (Price memory);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    function getEmaPriceNotOlderThan(bytes32 id, uint64 age) external view returns (Price memory);

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
    function getEmaPriceUnsafe(bytes32 id) external view returns (Price memory);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `heartbeatSecs`. 
    /// @param id The Price Feed ID of which to fetch the price.
    function getPrice(bytes32 id) external view returns (Price memory);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. 
    /// Reverts if the price wasn't updated sufficiently
    /// recently.
    function getPriceNotOlderThan(bytes32 id, uint64 age) external view returns (Price memory);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    /// 
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    function getPriceUnsafe(bytes32 id) external view returns (Price memory);
    
    /// @notice Legacy-compliant to get the required fee to update an array of price updates, which would be
    /// always 0 if relying on the Wit/Oracle bridging framework. 
    function getUpdateFee(bytes calldata) external view returns (uint256);
    
    /// @notice Parse `updates` and return price feeds of the given `ids` if they are all published
    /// within `minTimestamp` and `maxTimestamp`.
    ///
    /// You can use this method if you want to use a price updated at a fixed time and not the most recent price on-chain;
    /// otherwise, please consider using `updatePriceFeeds`. This method may store the price updates on-chain, if they
    /// happened to be more recent than the currently stored prices.
    ///
    /// @dev Reverts if there is no update for any of the given `ids` within the given time range.
    /// @param updates Array of price update reports.
    /// @param ids Array of price ids.
    /// @param minTimestamp minimum acceptable publishTime for the given `ids`.
    /// @param maxTimestamp maximum acceptable publishTime for the given `ids`.
    /// @return priceFeeds Array of parsed Prices corresponding to the given `ids` (with the same order).
    function parsePriceFeedUpdates(
            bytes[] calldata updates, 
            bytes32[] calldata ids, 
            uint64 minTimestamp,
            uint64 maxTimestamp
        ) external returns (Price[] memory);

    /// @notice Similar to `parsePriceFeedUpdates` but ensures the updates returned are
    /// the first updates published in `minTimestamp`. That is, if there are multiple updates for a given timestamp,
    /// this method will return the first update. This method may store the price updates on-chain, if they
    /// are more recent than the current stored prices.
    ///
    /// @dev Reverts if there is no update for any of the given `ids` within the given time range and uniqueness condition.
    /// @param updates Array of price update reports.
    /// @param ids Array of price ids.
    /// @param minTimestamp minimum acceptable publishTime for the given `ids`.
    /// @param maxTimestamp maximum acceptable publishTime for the given `ids`.
    /// @return priceFeeds Array of the Prices corresponding to the given `ids` (with the same order).
    function parsePriceFeedUpdatesUnique(
            bytes[] calldata updates, 
            bytes32[] calldata ids, 
            uint64 minTimestamp,
            uint64 maxTimestamp
        ) external returns (Price[] memory);

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
            bytes32[] calldata ids, 
            Witnet.Timestamp[] calldata timestamps
        ) external;
}
