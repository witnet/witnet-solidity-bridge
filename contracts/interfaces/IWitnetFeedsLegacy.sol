// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitnetFeedsLegacy {   
    struct RadonSLA {
        uint8 witNumWitnesses;
        uint64 witUnitaryReward;
    }
    function requestUpdate(bytes4, RadonSLA calldata) external payable returns (uint256 usedFunds);
}
