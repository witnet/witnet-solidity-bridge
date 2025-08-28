// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title The Witnet Randomness generator interface.
/// @author Witnet Foundation.
interface IWitRandomnessEvents {

    /// Emitted every time a new randomize is requested.
    event Randomizing(
        address indexed evmOrigin,
        address indexed evmRequester,
        Witnet.QueryId witOracleQueryId
    );
}
