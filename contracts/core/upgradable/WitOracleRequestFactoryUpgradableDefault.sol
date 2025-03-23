// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleRequestFactoryBaseUpgradable.sol";

contract WitOracleRequestFactoryUpgradableDefault
    is
        WitOracleRequestFactoryBaseUpgradable  
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleRequestFactoryUpgradableDefault).name;
    }

    constructor(
            address _witOracle,
            bytes32 _versionTag,
            bool _upgradable
        )
        WitOracleRequestFactoryBase(_witOracle)
        WitOracleRequestFactoryBaseUpgradable(
            _versionTag,
            _upgradable
        )
    {}
}
