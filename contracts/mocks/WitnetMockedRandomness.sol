// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetMockedOracle.sol";
import "../apps/WitnetRandomnessV2.sol";

/// @title Mocked implementation of `WitnetRandomness`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetRandomness` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedRandomness is WitnetRandomnessV2 {
    constructor(WitnetMockedOracle _wrb)
        WitnetRandomnessV2(_wrb)
    {}
}
