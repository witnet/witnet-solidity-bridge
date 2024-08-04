// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitRandomnessAdmin {
    function acceptOwnership() external;
    function baseFeeOverheadPercentage() external view returns (uint16);
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function transferOwnership(address) external;
    function settleBaseFeeOverheadPercentage(uint16) external;
    function settleWitnetQuerySLA(Witnet.RadonSLA calldata) external;
}