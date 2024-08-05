º// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitMockedOracle.sol";
import "../../contracts/apps/WitRandomnessV21.sol";

/// @title Mocked implementation of `WitRandomness`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitRandomness` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitMockedRandomness is WitRandomnessV21 {
    constructor(WitMockedOracle _witOracle)
        WitRandomnessV21(_witOracle, msg.sender)
    {}
}
