// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitRandomnessTypes.sol";

interface IWitRandomnessAdmin {
    function acceptOwnership() external;
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function settleConsumer(address consumer, uint24 maxCallbackGasLimit) external;
    function settleQueryParams(
            uint24 callbackGasLimit,
            uint16 extraFeePercentage, 
            uint16 minWitnesses, 
            uint64 minInclusionFees
        ) external;
    function settleRandomizeWaitingBlocks(uint16) external;
    function transferOwnership(address) external;
}
