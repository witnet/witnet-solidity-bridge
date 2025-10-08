// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IWitRandomness} from "./IWitRandomness.sol";
import {Witnet} from "../libs/Witnet.sol";

interface IWitRandomnessConsumer {
    /// Reports some Witnet-certified randomness. 
    /// @dev It should revert if called from an address other than `witRandomness()`.
    /// @dev Randomness metadata is stored in the `witRandomness()` address, indexed by `evmRandomizeBlock`.
    function reportRandomness(
            bytes32 randomness, 
            uint256 evmRandomizeBlock,
            uint256 evmFinalityBlock,
            Witnet.Timestamp witnetTimestamp,
            Witnet.TransactionHash witnetDrTxHash
        ) external;

    /// Returns the address of the one and only `IWitRandomness` instance that can provide Witnet-certified randomness.
    function witRandomness() external view returns (IWitRandomness);
}
