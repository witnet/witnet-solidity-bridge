// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitRandomnessAdminV3 {
    struct Settings {
        uint16 feeOverheadPercentage;
        uint24 maxCallbackGasLimit;
        uint16 minWitCommitteeSize;
        uint64 minWitInclusionFees;
        uint16 randomizeWaitingBlocks;
    }
    function acceptOwnership() external;
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function settings() external view returns (Settings memory);
    function settleFeeOverheadPercentage(uint16) external;
    function settleQueryDefaultParams(uint16, uint64, uint24) external;
    function settleRandomizeWaitingBlocks(uint16) external;
    function transferOwnership(address) external;
}
