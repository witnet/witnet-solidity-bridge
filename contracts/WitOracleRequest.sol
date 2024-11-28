// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleRequest.sol";

abstract contract WitOracleRequest
    is
        IWitOracleAppliance,
        IWitOracleRequest
{}
