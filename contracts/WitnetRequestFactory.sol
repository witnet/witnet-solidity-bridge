// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetOracleAppliance.sol";
import "./interfaces/IWitnetRadonRegistryEvents.sol";
import "./interfaces/IWitnetRequestFactory.sol";
import "./interfaces/IWitnetRequestFactoryEvents.sol";

abstract contract WitnetRequestFactory
    is
        IWitnetOracleAppliance, 
        IWitnetRadonRegistryEvents,
        IWitnetRequestFactory,
        IWitnetRequestFactoryEvents
{}
