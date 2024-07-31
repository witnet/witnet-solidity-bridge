// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetRequestFactoryAppliance.sol";
import "./interfaces/IWitnetRequestTemplate.sol";

abstract contract WitnetRequestTemplate
    is
        IWitnetRadonRegistryEvents,
        IWitnetRequestFactoryAppliance,
        IWitnetRequestFactoryEvents,
        IWitnetRequestTemplate
{}
