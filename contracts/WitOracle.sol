// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitOracleRadonRegistry.sol";
import "./WitOracleRequestFactory.sol";

import "./interfaces/IWitAppliance.sol";
import "./interfaces/IWitOracle.sol";
import "./interfaces/IWitOracleEvents.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitOracle
    is
        IWitAppliance,
        IWitOracle,
        IWitOracleEvents
{}
