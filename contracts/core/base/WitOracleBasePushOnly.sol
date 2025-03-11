// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../WitOraclePushOnly.sol";

/// @title Push-only WitOracle base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBasePushOnly
    is 
        WitOraclePushOnly
{
    function channel() virtual override public view returns (bytes4) {
        return Witnet.channel(address(this));
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _revertUnhandledException() virtual internal view {
        _revert(_revertUnhandledExceptionReason());
    }

    function _revertUnhandledExceptionReason() virtual internal pure returns (string memory);
}
