// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitnetRequest {
    /// A `IWitnetRequest` is constructed around a `bytes` value containing 
    /// a well-formed Witnet Data Request using Protocol Buffers.
    function bytecode() external view returns (bytes memory);

    /// Returns SHA256 hash of Witnet Data Request as CBOR-encoded bytes.
    function codehash() external view returns (bytes32);
}