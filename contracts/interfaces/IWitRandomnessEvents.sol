// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17 <0.9.0;

import {Witnet} from "../libs/Witnet.sol";

interface IWitRandomnessEvents {
    /// Emitted when a new randomize request gets posted to the Wit/Oracle framework.
    event Randomizing(
        address indexed evmRequester,
        uint256 randomizeBlock, 
        Witnet.QueryId witOracleQueryId
    );

    /// Emitted when some requested randomness gets delivered from Witnet.
    event Randomized(
        uint256 randomizeBlock,
        uint256 finalityBlock,
        bytes32 randomness
    );   
}
