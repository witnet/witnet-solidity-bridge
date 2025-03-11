// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseQueriableTrustless.sol";

/// @title Witnet Request Board "trustless" implementation contract for regular EVM-compatible chains.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustlessDefaultV22
    is 
        WitOracleBaseQueriableTrustless
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleTrustlessDefaultV22).name;
    }

    constructor(
            EvmImmutables memory _immutables,
            uint256 _queryAwaitingBlocks,
            uint256 _queryReportingStake,
            WitOracleRadonRegistry _registry
        )
        WitOracleBaseQueriable(
            _immutables,
            _registry
        )
        WitOracleBaseQueriableTrustless(
            _queryAwaitingBlocks,
            _queryReportingStake
        )
    {}
}
