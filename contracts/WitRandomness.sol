// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleEvents.sol";
import "./interfaces/IWitRandomness.sol";
import "./interfaces/IWitRandomnessEvents.sol";

abstract contract WitRandomness
    is
        IWitOracleAppliance,
        IWitOracleEvents,
        IWitRandomness,
        IWitRandomnessEvents
{}
