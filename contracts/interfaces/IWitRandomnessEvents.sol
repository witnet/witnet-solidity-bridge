// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../libs/Witnet.sol";

/// @title The Witnet Randomness generator interface.
/// @author Witnet Foundation.
interface IWitRandomnessEvents {

    /// Emitted every time a new randomize is requested.
    event Randomizing(
            address evmOrigin,
            address evmSender,
            uint256 witOracleQueryId
    );
}
