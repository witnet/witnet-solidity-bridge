// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

/// @title The Witnet Price Feed basic interface.
/// @dev Guides implementation of active price feed polling contracts.
/// @author The Witnet Foundation.

interface IWitnetPriceFeed {

    /// Signals that a new price update request is being posted to the Witnet Request Board
    event PriceFeeding(address indexed from, uint256 queryId, uint256 extraFee);

    /// Estimates minimum fee amount in native currency to be paid when 
    /// requesting a new price update.
    /// @dev Actual fee depends on the gas price of the `requestUpdate()` transaction.
    /// @param _gasPrice Gas price expected to be paid when calling `requestUpdate()`
    function estimateUpdateFee(uint256 _gasPrice) external view returns (uint256);

    /// Returns result of the last valid price update request successfully solved by the Witnet oracle.
    function lastPrice() external view returns (int256);

    /// Returns the EVM-timestamp when last valid price was reported back from the Witnet oracle.
    function lastTimestamp() external view returns (uint256);    

    /// Returns tuple containing last valid price and timestamp, as well as status code of latest update
    /// request that got posted to the Witnet Request Board.
    /// @return _lastPrice Last valid price reported back from the Witnet oracle.
    /// @return _lastTimestamp EVM-timestamp of the last valid price.
    /// @return _lastDrTxHash Hash of the Witnet Data Request that solved the last valid price.
    /// @return _latestUpdateStatus Status code of the latest update request.
    function lastValue() external view returns (
        int _lastPrice,
        uint _lastTimestamp,
        bytes32 _lastDrTxHash,
        uint _latestUpdateStatus
    );

    /// Returns identifier of the latest update request posted to the Witnet Request Board.
    function latestQueryId() external view returns (uint256);

    /// Returns hash of the Witnet Data Request that solved the latest update request.
    /// @dev Returning 0 while the latest update request remains unsolved.
    function latestUpdateDrTxHash() external view returns (bytes32);

    /// Returns error message of latest update request posted to the Witnet Request Board.
    /// @dev Returning empty string if the latest update request remains unsolved, or
    /// @dev if it was succesfully solved with no errors.
    function latestUpdateErrorMessage() external view returns (string memory);

    /// Returns status code of latest update request posted to the Witnet Request Board:
    /// @dev Status codes:
    /// @dev   - 200: update request was succesfully solved with no errors
    /// @dev   - 400: update request was solved with errors
    /// @dev   - 404: update request was not solved yet 
    function latestUpdateStatus() external view returns (uint256);

    /// Returns `true` if latest update request posted to the Witnet Request Board 
    /// has not been solved yet by the Witnet oracle.
    function pendingUpdate() external view returns (bool);

    /// Posts a new price update request to the Witnet Request Board. Requires payment of a fee
    /// that depends on the value of `tx.gasprice`. See `estimateUpdateFee(uint256)`.
    /// @dev If previous update request was not solved yet, calling this method again allows
    /// @dev upgrading the update fee if called with a higher `tx.gasprice` value.
    function requestUpdate() external payable;

    /// Tells whether this contract implements the interface defined by `interfaceId`. 
    /// @dev See the corresponding https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
    /// @dev to learn more about how these ids are created.
    function supportsInterface(bytes4) external view returns (bool);
}
