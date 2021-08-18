// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBase.sol";

contract WitnetRequest
    is
        IWitnetRequest
{
    using Witnet for bytes;

    /// Contains a well-formed Witnet Data Request, encoded using Protocol Buffers.
    bytes public override bytecode;

    constructor(bytes memory _bytecode) {
        bytecode = _bytecode;
    }

    /// Applies Witnet-compatible hash function over the `bytecode()` in order to 
    /// uniquely identify every possible well-formed Data Request.
    function codehash() external view override returns (bytes32) {
      return bytecode.computeCodehash();
    }
}
