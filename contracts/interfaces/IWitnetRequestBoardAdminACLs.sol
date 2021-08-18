// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title Witnet Request Board ACLs administration interface.
/// @author The Witnet Foundation.
interface IWitnetRequestBoardAdminACLs {
    event ReportersSet(address[] reporters);
    event ReportersUnset(address[] reporters);

    /// Tells whether given address is included in the active reporters control list.
    function isReporter(address) external view returns (bool);

    /// Adds given addresses to the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersSet` event. 
    function setReporters(address[] calldata reporters) external;

    /// Removes given addresses from the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersUnset` event. 
    function unsetReporters(address[] calldata reporters) external;
}
