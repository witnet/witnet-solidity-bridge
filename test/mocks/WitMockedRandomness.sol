º// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedOracle.sol";
import "../../contracts/apps/WitRandomnessV21.sol";

/// @title Mocked implementation of `WitnetRandomness`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetRandomness` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedRandomness is WitRandomnessV21 {
    constructor(WitMockedOracle _wrb)
        WitRandomnessV21(_wrb, msg.sender)
    {}
}
