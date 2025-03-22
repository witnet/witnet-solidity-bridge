// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseQueriableTrustable.sol";

/// @title Queriable WitOracle "trustable" implementation.
/// @author The Witnet Foundation
contract WitOracleTrustableDefault
    is 
        WitOracleBaseQueriableTrustable
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleTrustableDefault).name;
    }

    constructor(
            EvmImmutables memory _immutables,
            WitOracleRadonRegistry _registry,
            bytes32 _versionTag
        )
        WitOracleBaseQueriable(
            _immutables,
            _registry
        )
        WitOracleBaseQueriableTrustable(_versionTag)
    {}
}
