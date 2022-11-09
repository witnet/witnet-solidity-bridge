// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

/// @title Witnet Request Board emitting events interface.
/// @author The Witnet Foundation.
interface IWitnetRequestsAdmin {

    event SetBlocks(address indexed from, address contractAddr);
    event SetBytecodes(address indexed from, address contractAddr);
    event SetDecoder(address indexed from, address contractAddr);

    function setBlocks(address) external;
    function setBytecodes(address) external;
    function setDecoder(address) external;

}