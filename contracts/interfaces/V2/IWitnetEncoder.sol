// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitnetEncoder {
    function encode(address) external pure returns (bytes memory);
    function encode(bool) external pure returns (bytes memory);
    function encode(bytes calldata) external pure returns (bytes memory);
    function encode(int256) external pure returns (bytes memory);
    function encode(uint256) external pure returns (bytes memory);
    function encode(string calldata) external pure returns (bytes memory);
}
