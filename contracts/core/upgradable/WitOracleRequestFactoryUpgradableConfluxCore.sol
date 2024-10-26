// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleRequestFactoryUpgradableDefault.sol";

contract WitOracleRequestFactoryUpgradableConfluxCore
    is
        WitOracleRequestFactoryUpgradableDefault  
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleRequestFactoryUpgradableConfluxCore).name;
    }

    constructor(
            WitOracle _witOracle,
            bytes32 _versionTag,
            bool _upgradable
        )
        WitOracleRequestFactoryUpgradableDefault(
            _witOracle,
            _versionTag,
            _upgradable
        )
    {}

    function _cloneDeterministic(bytes32 _salt)
        override internal
        returns (address _instance)
    {
        bytes memory ptr = _cloneBytecodePtr();
        assembly {
            // CREATE2 new instance:
            _instance := create2(0, ptr, 0x37, _salt)
        }
        emit Cloned(msg.sender, self(), _instance);
    }
}
