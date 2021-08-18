// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/IWitnetRadon.sol";
import "../libs/Witnet.sol";

abstract contract WitnetRadonBase is IWitnetRadon {
    using Witnet for bytes;
    bytes public override bytecode;

    /// Applies Witnet-compatible hash function over the `bytecode()` in order to 
    /// uniquely identify every possible well-formed Radon script.
    function codehash() external view override returns (bytes32) {
      return bytecode.computeCodehash();
    }
}
