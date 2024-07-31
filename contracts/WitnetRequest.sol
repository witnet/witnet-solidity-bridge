// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IWitnetRequest.sol";
import "./interfaces/IWitnetRequestFactoryAppliance.sol";

abstract contract WitnetRequest
    is
        IWitnetRequestFactoryAppliance,
        IWitnetRequest
{}
