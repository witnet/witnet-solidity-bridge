// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../defaults/WitnetRadonRegistryDefault.sol";

contract WitnetRadonRegistryNoSha256
    is
        WitnetRadonRegistryDefault
{
    function class() virtual override public view returns (string memory) {
        return type(WitnetRadonRegistryNoSha256).name;
    }

    constructor(bool _upgradable, bytes32 _versionTag)
        WitnetRadonRegistryDefault(_upgradable, _versionTag)
    {}
    
    function _witnetHash(bytes memory chunk) virtual override internal pure returns (bytes32) {
        return keccak256(chunk);
    }
}