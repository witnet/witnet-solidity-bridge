// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitFeedsLegacy {   
    struct RadonSLA {
        uint8 witNumWitnesses;
        uint64 witUnitaryReward;
    }
    function estimateUpdateBaseFee(uint256 evmGasPrice) external view returns (uint);
    function lookupWitnetBytecode(bytes4) external view returns (bytes memory);
    function requestUpdate(bytes4, RadonSLA calldata) external payable returns (uint256 usedFunds);
    function witnet() external view returns (address);
}
