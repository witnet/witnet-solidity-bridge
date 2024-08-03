// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetMockedOracle.sol";
import "../../contracts/apps/WitnetRandomnessV21.sol";

/// @title Mocked implementation of `WitnetRandomness`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetRandomness` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedRandomness is WitnetRandomnessV21 {
    constructor(WitnetMockedOracle _wrb)
        WitnetRandomnessV21(_wrb, msg.sender)
    {}
}
