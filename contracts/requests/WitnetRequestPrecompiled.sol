// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

contract WitnetRequestPrecompiled
    is
        IWitnetRequest
{
    /// Contains a well-formed Witnet Data Request, encoded using Protocol Buffers.
    bytes public override bytecode;

    /// Returns SHA256 hash of Witnet Data Request as CBOR-encoded bytes.
    bytes32 public override hash;

    constructor(bytes memory _bytecode) {
        bytecode = _bytecode;
        hash = _witnetHash(_bytecode);
    }

    function _witnetHash(bytes memory chunk)
        virtual internal view
        returns (bytes32)
    {
        if (
                block.chainid == 1101           // polygon.zkevm.mainnet
                    || block.chainid == 1442    // polygon.zkevm.goerli
                    || block.chainid == 534353  // scroll.goerli
        ) {
            return keccak256(chunk);
        } else {
            return sha256(chunk);
        }
    }
}
