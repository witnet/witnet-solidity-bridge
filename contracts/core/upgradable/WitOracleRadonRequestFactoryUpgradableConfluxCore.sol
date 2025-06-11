// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleRadonRequestFactoryUpgradableDefault.sol";

contract WitOracleRadonRequestFactoryUpgradableConfluxCore
    is
        WitOracleRadonRequestFactoryUpgradableDefault  
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleRadonRequestFactoryUpgradableConfluxCore).name;
    }

    constructor(
            address _witOracleRadonRequestModalsBuilder,
            address _witOracleRadonRequestTemplatesBuilder,
            bytes32 _versionTag,
            bool _upgradable
        )
        WitOracleRadonRequestFactoryUpgradableDefault(
            _witOracleRadonRequestModalsBuilder,
            _witOracleRadonRequestTemplatesBuilder,
            _versionTag,
            _upgradable
        )
    {}

    function _checkCloneWasDeployed(address _clone) virtual override internal pure {}
}
