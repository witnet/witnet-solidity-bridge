// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetOracleAppliance.sol";
import "./interfaces/IWitnetRequestFactory.sol";
import "./interfaces/IWitnetRequestFactoryEvents.sol";
import "./interfaces/IWitnetRequestRegistryEvents.sol";

abstract contract WitnetRequestFactory
    is
        IWitnetOracleAppliance, 
        IWitnetRequestFactory,
        IWitnetRequestFactoryEvents,
        IWitnetRequestRegistryEvents
{}
