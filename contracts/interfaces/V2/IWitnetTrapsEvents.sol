// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./IWitnetTraps.sol";

interface IWitnetTrapsEvents {
    event Funded(address indexed to, uint256 newBalance);
    event Rewarded(address indexed from, address indexed to, uint256 reward);
    event Withdrawn(address indexed by, uint256 withdrawn);
    event Trap(bytes32 indexed id, address indexed feeder, IWitnetTraps.SLA sla);
}
