// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetRandomness.sol";
import "./interfaces/IWitnetRandomnessAdmin.sol";

abstract contract WitnetRandomness
    is
        IWitnetRandomness,
        IWitnetRandomnessAdmin
{
    /// Deploys a minimal-proxy clone in which the `witnetRandomnessRequest` is owned by the cloner,
    /// @dev This function should always provide a new address, no matter how many times 
    /// @dev is actually called from the same `msg.sender`.
    function clone() virtual external returns (WitnetRandomness);

    /// Deploys a minimal-proxy clone in which the `witnetRandomnessRequest` is owned by the cloner,
    /// and whose address will be determined by the provided salt. 
    /// @dev This function uses the CREATE2 opcode and a `_salt` to deterministically deploy
    /// @dev the clone. Using the same `_salt` multiple time will revert, since
    /// @dev no contract can be deployed more than once at the same address.
    function cloneDeterministic(bytes32 salt) virtual external returns (WitnetRandomness);
}