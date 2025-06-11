// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleRadonRequestFactoryBaseUpgradable.sol";

contract WitOracleRadonRequestFactoryUpgradableDefault
    is
        WitOracleRadonRequestFactoryBaseUpgradable  
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleRadonRequestFactoryUpgradableDefault).name;
    }

    constructor(
            address _witOracleRadonRequestModalsBuilder,
            address _witOracleRadonRequestTemplatesBuilder,
            bytes32 _versionTag,
            bool _upgradable
        )
        WitOracleRadonRequestFactoryBase(
            _witOracleRadonRequestModalsBuilder,
            _witOracleRadonRequestTemplatesBuilder
        )
        WitOracleRadonRequestFactoryBaseUpgradable(
            _versionTag,
            _upgradable
        )
    {}
}
