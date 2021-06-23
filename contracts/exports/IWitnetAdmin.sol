// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitnetAdmin {
    event OwnershipTransferred(address indexed from, address indexed to);
    function owner() external view returns (address);
    function transferOwnership(address) external;
}
