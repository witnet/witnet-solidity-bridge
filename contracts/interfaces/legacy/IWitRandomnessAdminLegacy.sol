// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/Witnet.sol";

interface IWitRandomnessAdminV2 {
    struct WitParams {
        uint16 minWitCommitteeSize;
        uint64 minWitInclusionFees;
    }
    function acceptOwnership() external;
    function baseFeeOverheadPercentage() external view returns (uint16);
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function settleBaseFeeOverheadPercentage(uint16) external;
    function settleWitOracleRequiredParams(WitParams calldata) external;
    function transferOwnership(address) external;
    function witOracleRequiredParams() external view returns (WitParams memory);
}