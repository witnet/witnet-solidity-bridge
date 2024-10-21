// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../base/WitOracleBaseUpgradable.sol";

/// @title Witnet Request Board "trustless" implementation contract for regular EVM-compatible chains.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleTrustlessUpgradableDefault
    is 
        WitOracleBaseUpgradable
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleTrustlessUpgradableDefault).name;
    }

    constructor(
            EvmImmutables memory _immutables,
            uint256 _queryAwaitingBlocks,
            uint256 _queryReportingStake,
            WitOracleRadonRegistry _registry,
            // WitOracleRequestFactory _factory,
            bytes32 _versionTag,
            bool _upgradable
        )
        WitOracleBase(
            _immutables,
            _registry
            // _factory
        )
        WitOracleBaseTrustless(
            _queryAwaitingBlocks,
            _queryReportingStake
        )
        WitOracleBaseUpgradable(
            _versionTag,
            _upgradable
        )
    {}
}
