// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../libs/WitnetV2.sol";

/// @title The Witnet Randomness generator interface.
/// @author Witnet Foundation.
interface IWitnetRandomnessEvents {
    event Randomizing(
            uint256 blockNumber, 
            uint256 evmTxGasPrice,
            uint256 evmRandomizeFee,
            uint256 witnetQueryId, 
            WitnetV2.RadonSLA witnetQuerySLA
        );
}
