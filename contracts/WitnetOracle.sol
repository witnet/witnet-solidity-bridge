// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBytecodes.sol";
import "./WitnetRequestFactory.sol";

import "./interfaces/IWitnetAppliance.sol";
import "./interfaces/IWitnetOracle.sol";
import "./interfaces/IWitnetOracleEvents.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetOracle
    is
        IWitnetAppliance,
        IWitnetOracle,
        IWitnetOracleEvents
{}
