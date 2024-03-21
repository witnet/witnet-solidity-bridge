// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../defaults/WitnetRequestBytecodesDefault.sol";

contract WitnetRequestBytecodesNoSha256
    is
        WitnetRequestBytecodesDefault
{
    function class() virtual override public view returns (string memory) {
        return type(WitnetRequestBytecodesNoSha256).name;
    }

    constructor(bool _upgradable, bytes32 _versionTag)
        WitnetRequestBytecodesDefault(_upgradable, _versionTag)
    {}
    
    function _witnetHash(bytes memory chunk) virtual override internal pure returns (bytes32) {
        return keccak256(chunk);
    }
}