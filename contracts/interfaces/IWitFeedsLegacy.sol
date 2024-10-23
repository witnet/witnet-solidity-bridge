// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitFeedsLegacy {   
    struct RadonSLA {
        uint8 witNumWitnesses;
        uint64 witUnitaryReward;
    }
    function estimateUpdateBaseFee(uint256 evmGasPrice) external view returns (uint);
    function latestUpdateResponseStatus(bytes4 feedId) external view returns (Witnet.QueryResponseStatus);
    function lookupWitnetBytecode(bytes4) external view returns (bytes memory);
    
    function requestUpdate(bytes4, RadonSLA calldata) external payable returns (uint256 usedFunds);
    function witnet() external view returns (address);
}
