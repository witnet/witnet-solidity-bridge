// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleLegacy.sol";
import "../libs/Witnet.sol";

interface IWitFeedsLegacy {   
    struct RadonSLA {
        uint8 witCommitteeCapacity;
        uint64 witCommitteeUnitaryReward;
    }
    function estimateUpdateBaseFee(uint256 evmGasPrice) external view returns (uint);
    function latestUpdateResponse(bytes4 feedId) external view returns (Witnet.QueryResponse memory);
    function latestUpdateResponseStatus(bytes4 feedId) external view returns (IWitOracleLegacy.QueryResponseStatus);
    function latestUpdateResultError(bytes4 feedId) external view returns (IWitOracleLegacy.ResultError memory);
    function lookupWitnetBytecode(bytes4) external view returns (bytes memory);
    function requestUpdate(bytes4, RadonSLA calldata) external payable returns (uint256 usedFunds);
    function witnet() external view returns (address);
}
