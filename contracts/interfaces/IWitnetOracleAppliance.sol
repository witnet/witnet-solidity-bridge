// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../WitnetOracle.sol";
import "./IWitnetAppliance.sol";

abstract contract IWitnetOracleAppliance
    is
        IWitnetAppliance
{
    /// @notice Returns the WitnetOracle address that this appliance is bound to.
    function witnet() virtual external view returns (WitnetOracle);
}
