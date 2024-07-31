// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitnetOracleAppliance.sol";
import "./interfaces/IWitnetOracleEvents.sol";
import "./interfaces/IWitnetRandomness.sol";
import "./interfaces/IWitnetRandomnessEvents.sol";

abstract contract WitnetRandomness
    is
        IWitnetOracleAppliance,
        IWitnetOracleEvents,
        IWitnetRandomness,
        IWitnetRandomnessEvents
{}
