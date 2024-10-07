// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "./Payable.sol";

abstract contract Escrowable
    is
        Payable
{
    event Burnt(address indexed from, uint256 value);
    event Staked(address indexed from, uint256 value);
    event Slashed(address indexed from, uint256 value);
    event Unstaked(address indexed from, uint256 value);
    event Withdrawn(address indexed from, uint256 value);

    struct Escrow {
        uint256 balance;
        uint256 collateral;
    }

    receive() virtual external payable;

    function collateralOf(address) virtual external view returns (uint256);
    function balanceOf(address) virtual external view returns (uint256);
    function withdraw() virtual external returns (uint256);

    function __burn(address from, uint256 value) virtual internal;
    function __deposit(address from, uint256 value) virtual internal;
    function __slash(address from, address to, uint256 value) virtual internal;
    function __stake(address from, uint256 value) virtual internal;
    function __unstake(address from, uint256 value) virtual internal;
}