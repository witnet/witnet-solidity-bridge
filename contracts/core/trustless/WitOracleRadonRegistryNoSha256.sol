// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleRadonRegistryDefault.sol";

contract WitOracleRadonRegistryNoSha256
    is
        WitOracleRadonRegistryDefault
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleRadonRegistryNoSha256).name;
    }

    constructor(bool _upgradable, bytes32 _versionTag)
        WitOracleRadonRegistryDefault(_upgradable, _versionTag)
    {}
    
    function _witOracleHash(bytes memory chunk) virtual override internal pure returns (bytes32) {
        return keccak256(chunk);
    }
}