// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWitnetAppliance {

    /// @notice Returns the name of the actual contract implementing the logic of this Witnet appliance.
    function class() external view returns (string memory);

    /// @notice Returns the ERC-165 id of the minimal functionality expected for this appliance.
    function specs() external view returns (bytes4);

}
