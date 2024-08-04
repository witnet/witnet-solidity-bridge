// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleRequest.sol";

abstract contract WitOracleRequest
    is
        IWitOracleAppliance,
        IWitOracleRequest
{}
