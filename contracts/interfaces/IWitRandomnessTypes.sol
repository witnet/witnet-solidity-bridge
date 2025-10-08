// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17 <0.9.0;

import {Witnet} from "../libs/Witnet.sol";

interface IWitRandomnessTypes {
    /// Randomization status for some specified block number.
    enum RandomizeStatus {
        Void,
        Awaiting,
        Ready,
        Error,
        Finalizing
    }
}
