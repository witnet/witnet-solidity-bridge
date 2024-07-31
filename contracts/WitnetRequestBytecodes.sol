// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetAppliance.sol";
import "./interfaces/IWitnetRequestRegistry.sol";
import "./interfaces/IWitnetRequestRegistryEvents.sol";

abstract contract WitnetRequestBytecodes
    is
        IWitnetAppliance,
        IWitnetRequestRegistry,
        IWitnetRequestRegistryEvents
{}
