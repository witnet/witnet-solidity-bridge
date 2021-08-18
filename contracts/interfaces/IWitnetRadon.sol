// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitnetRadon {
    /// A `IWitnetRadon` is constructed around a `bytes` value containing 
    /// a well-formed Witnet Radon Script using Protocol Buffers.
    function bytecode() external view returns (bytes memory);

    /// Applies hash function over the `bytecode()` in order to uniquely 
    /// identify every possible well-formed Radon script.
    function codehash() external view returns (bytes32);
}
