// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleRequestFactoryDefault.sol";

contract WitOracleRequestFactoryCfxCore
    is
        WitOracleRequestFactoryDefault
{
    constructor(
            WitOracle _witOracle,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitOracleRequestFactoryDefault(_witOracle, _upgradable, _versionTag)
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