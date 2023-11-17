// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libs/Witnet.sol";

interface IWitnetConsumer {
    function reportWitnetQueryResult(uint256, WitnetCBOR.CBOR calldata) external;
    function reportWitnetQueryError(uint256, Witnet.ResultErrorCodes, uint) external;
}