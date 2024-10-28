// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title Witnet Request Board basic administration interface.
/// @author The Witnet Foundation.
interface IWitOracleAdmin {
    
    event OwnershipTransferred(address indexed from, address indexed to);

    /// Gets admin/owner address.
    function owner() external view returns (address);

    /// Transfers ownership.
    function transferOwnership(address) external;

    /// Accepts ownership.
    function acceptOwnership() external;
}
