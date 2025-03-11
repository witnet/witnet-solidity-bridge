// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitPythErrors {

    /// @notice Function arguments are invalid (e.g., the arguments lengths mismatch)
    /// @dev Signature: 0xa9cb9e0d
    error InvalidArgument();
    
    /// @notice Either not enough fees were paid to the Wit/Oracle for solving at least one of the updates,
    /// or not enough number of witnesses were required for solving at least one of the updates. 
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
