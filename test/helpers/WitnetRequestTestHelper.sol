// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
import "../../contracts/libs/Witnet.sol";

/**
 * @title The serialized form of a Witnet data request
 */
contract WitnetRequestTestHelper is IWitnetRequest {

    using Witnet for bytes;

    constructor(bytes memory _bytecode) {
        bytecode = _bytecode;
    }

    /// Contains a well-formed Witnet Data Request, encoded using Protocol Buffers.
    bytes public override bytecode;

    /// Applies Witnet-compatible hash function over the `bytecode()` in order to 
    /// uniquely identify every possible well-formed Data Request.
    function hash() public view override returns (bytes32) {
        return bytecode.hash();
    }

    /// Modifies the Witnet Data Request bytecode.
    function modifyBytecode(bytes memory _bytecode) public {
        bytecode = _bytecode;
    }
}
