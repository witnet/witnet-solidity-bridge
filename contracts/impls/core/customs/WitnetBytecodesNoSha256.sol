// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetBytecodesDefault.sol";

contract WitnetBytecodesNoSha256 is WitnetBytecodesDefault {

    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetBytecodesDefault(_upgradable, _versionTag)
    {}
    
    function _witnetHash(bytes memory chunk) virtual override internal pure returns (bytes32) {
        return keccak256(chunk);
    }
}