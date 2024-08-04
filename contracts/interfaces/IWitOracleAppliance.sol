// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../WitOracle.sol";
import "./IWitAppliance.sol";

abstract contract IWitOracleAppliance
    is
        IWitAppliance
{
    /// @notice Returns the WitOracle address that this appliance is bound to.
    function witnet() virtual external view returns (WitOracle);
}
