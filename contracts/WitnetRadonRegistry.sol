// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetAppliance.sol";
import "./interfaces/IWitnetRadonRegistry.sol";
import "./interfaces/IWitnetRadonRegistryEvents.sol";

abstract contract WitnetRadonRegistry
    is
        IWitnetAppliance,
        IWitnetRadonRegistry,
        IWitnetRadonRegistryEvents
{}
