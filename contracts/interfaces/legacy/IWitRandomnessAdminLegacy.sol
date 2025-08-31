// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitRandomnessLegacy.sol";

interface IWitRandomnessAdminV2 {
    struct WitParams {
        uint16 minWitCommitteeSize;
        uint64 minWitInclusionFees;
    }
    function acceptOwnership() external;
    function baseFeeOverheadPercentage() external view returns (uint16);
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function transferOwnership(address) external;
    function settleBaseFeeOverheadPercentage(uint16) external;
    function settleWitnetQuerySLA(IWitRandomnessLegacy.RandomizeQueryParams calldata) external;
}