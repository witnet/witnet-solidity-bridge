// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../WitOracle.sol";

abstract contract IWitOracleAppliance
    is
        IWitAppliance
{
    /// @notice Returns the WitOracle address that this appliance is bound to.
    function witOracle() virtual external view returns (WitOracle);
}
