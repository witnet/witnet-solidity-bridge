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

    struct PythPrice {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    /// @notice Returns the exponentially-weighted moving average price.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Price Feed ID of which to fetch the EMA price.
    function getEmaPrice(ID id) external view returns (PythPrice memory);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    function getEmaPriceNotOlderThan(ID id, uint64 age) external view returns (PythPrice memory);

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
    function getEmaPriceUnsafe(ID id) external view returns (PythPrice memory);

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
    function getPrice(ID id) external view returns (PythPrice memory);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. 
    /// Reverts if the price wasn't updated sufficiently
    /// recently.
    function getPriceNotOlderThan(ID id, uint64 age) external view returns (PythPrice memory);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    /// 
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    function getPriceUnsafe(ID id) external view returns (PythPrice memory);
    
    /// @notice Legacy-compliant to get the required fee to update an array of price updates, which would be
    /// always 0 if relying on the Wit/Oracle bridging framework. 
    function getUpdateFee(bytes calldata) external view returns (uint256);
}
