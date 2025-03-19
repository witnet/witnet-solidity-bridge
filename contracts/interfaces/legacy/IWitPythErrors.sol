// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitPythErrors {

    /// @notice Requested price deviated too much after previous update.
    /// @dev Signature: 0x7b0d2bb5
    error DeviantPrice();

    // /// @notice Attempting to update a price before cooldown period expires.
    // /// @dev Signature: 0x0fbbc581
    // error HotPrice();

    /// @notice Function arguments are invalid (e.g., the arguments lengths mismatch)
    /// @dev Signature: 0xa9cb9e0d
    error InvalidArgument();
    
    /// @notice Either the number of witnesses that solved a price update is not within
    /// the settled range in this contract, or an EMA is being asked for a price feed
    /// that's not settled for the EMA to be computed. 
    // Signature: 0x63daeb77
    error InvalidGovernanceTarget();
    
    /// @notice Update data is coming from an invalid Wit/Oracle Radon Hash.
    /// @dev Signature: 0xe60dce71
    error InvalidUpdateDataSource();

    /// @notice Update data is invalid (e.g. badly serialized, or bad proof was provided).
    /// @dev Signature: 0xe69ffece
    error InvalidUpdateData();

    /// @notice There is no fresh update, whereas expected fresh updates.
    /// @dev Signature: 0xde2c57fa
    error NoFreshUpdate();
    
    /// @notice Price feed not found or it is not pushed on-chain yet.
    /// @dev Signature: 0x14aebe68
    error PriceFeedNotFound();

    /// @notice There is no price feed found within the given range or it does not exist.
    /// @dev Signature: 0x45805f5d
    error PriceFeedNotFoundWithinRange();

    /// @notice Requested price is stale.
    /// @dev Signature: 0x19abf40e
    error StalePrice();
}
