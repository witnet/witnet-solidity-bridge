// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../WitOraclePushOnly.sol";
import "../../WitOracleRadonRegistry.sol";

/// @title Push-only WitOracle base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBasePushOnly
    is 
        WitOraclePushOnly
{
    function channel() virtual override public view returns (bytes4) {
        return Witnet.channel(address(this));
    }

    IWitOracleRadonRegistry public immutable override registry;

    constructor(WitOracleRadonRegistry _registry) {
        _require(
            address(_registry).code.length > 0,
            "inexistent registry"
        );
        _require(
            _registry.specs() == type(IWitOracleRadonRegistry).interfaceId, 
            "uncompliant registry"
        );
        registry = _registry;
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _revertUnhandledException() virtual internal view {
        _revert(_revertUnhandledExceptionReason());
    }

    function _revertUnhandledExceptionReason() virtual internal pure returns (string memory);
}
