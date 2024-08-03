// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetOracleAppliance.sol";
import "./interfaces/IWitnetRequest.sol";

abstract contract WitnetRequest
    is
        IWitnetOracleAppliance,
        IWitnetRequest
{}
