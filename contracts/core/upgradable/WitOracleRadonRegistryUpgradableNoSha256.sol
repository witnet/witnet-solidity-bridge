// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleRadonRegistryBaseUpgradable.sol";

contract WitOracleRadonRegistryUpgradableNoSha256
    is
        WitOracleRadonRegistryBaseUpgradable
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleRadonRegistryUpgradableNoSha256).name;
    }
    
    function _witOracleHash(bytes memory chunk) virtual override internal pure returns (bytes32) {
        return keccak256(chunk);
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
