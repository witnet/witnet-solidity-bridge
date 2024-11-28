// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleRadonRegistryBaseUpgradable.sol";

/// @title Witnet Request Board "trustless" implementation contract for regular EVM-compatible chains.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleRadonRegistryUpgradableDefault
    is 
        WitOracleRadonRegistryBaseUpgradable
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleRadonRegistryUpgradableDefault).name;
    }

    constructor(
            bytes32 _versionTag,
            bool _upgradable
        )
        WitOracleRadonRegistryBaseUpgradable(
            _versionTag,
            _upgradable
        )
    {}
}
