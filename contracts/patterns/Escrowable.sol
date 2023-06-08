// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "./Payable.sol";

abstract contract Escrowable
    is
        Payable
{
    event Staked(address indexed from, uint256 value);
    event Slashed(address indexed from, address indexed to, uint256 value);
    
    constructor(IERC20 _currency)
        Payable(_currency)
    {}

    receive() virtual external payable;

    function atStakeBy(address) virtual external view returns (uint256);
    function balanceOf(address) virtual external view returns (uint256);
    function withdraw() virtual external returns (uint256);

    function __receive(address from, uint256 value) virtual internal;
    function __stake(address from, uint256 value) virtual internal;
    function __slash(address from, address to, uint256 value) virtual internal;
}