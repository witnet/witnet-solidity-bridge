// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../libs/Secp256k1.sol";

contract TestSecp256k1 {

    string internal result;

    function recoverWitPublicKeyX(bytes memory witSignature, address evmAddr)
        public pure returns (bytes32)
    {
        bytes32 digest = keccak256(abi.encodePacked(evmAddr));
        if (witSignature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(witSignature, 0x20))
                s := mload(add(witSignature, 0x40)) 
                v := byte(0, mload(add(witSignature, 0x60)))
            }
            if (
                uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
                    && (v == 27 || v == 28)
            ) {
                (uint256 _x,) = Secp256k1.recover(uint256(digest), v - 27, uint256(r), uint256(s));
                return bytes32(_x);
            }
        }
        return bytes32(0);
    }

    function recoverWitAddr(bytes memory witSignature, address evmAddr) 
        public pure returns (bytes20, bytes20, bytes20, bytes20)
    {
        bytes32 _publicKeyX = recoverWitPublicKeyX(witSignature, evmAddr);
        return (
            bytes20(sha256(abi.encodePacked(bytes1(0x00), _publicKeyX))),
            bytes20(sha256(abi.encodePacked(bytes1(0x01), _publicKeyX))),
            bytes20(sha256(abi.encodePacked(bytes1(0x02), _publicKeyX))),
            bytes20(sha256(abi.encodePacked(bytes1(0x03), _publicKeyX)))
        );
    }
}