// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleRadonRegistryEvents.sol";
import "./interfaces/IWitOracleRequestFactory.sol";
import "./interfaces/IWitOracleRequestFactoryEvents.sol";

abstract contract WitOracleRequestFactory
    is
        IWitOracleAppliance, 
        IWitOracleRadonRegistryEvents,
        IWitOracleRequestFactory,
        IWitOracleRequestFactoryEvents
{}
