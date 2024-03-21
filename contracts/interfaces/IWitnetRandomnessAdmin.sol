// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/WitnetV2.sol";

interface IWitnetRandomnessAdmin {
    function owner() external view returns (address);
    function acceptOwnership() external;
    function pendingOwner() external returns (address);
    function transferOwnership(address) external;
    function settleWitnetRandomnessSLA(Witnet.RadonSLA calldata) external returns (bytes32);
}