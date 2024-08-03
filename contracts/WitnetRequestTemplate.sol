// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetOracleAppliance.sol";
import "./interfaces/IWitnetRadonRegistryEvents.sol";
import "./interfaces/IWitnetRequestFactoryEvents.sol";
import "./interfaces/IWitnetRequestTemplate.sol";

abstract contract WitnetRequestTemplate
    is
        IWitnetOracleAppliance,
        IWitnetRadonRegistryEvents,
        IWitnetRequestFactoryEvents,
        IWitnetRequestTemplate
{}
