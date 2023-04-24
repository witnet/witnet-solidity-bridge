// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../WitnetRequestBoard.sol";

interface IWitnetFeeds {
    function dataType() external view returns (WitnetV2.RadonDataTypes);
    function prefix() external view returns (string memory);
    function registry() external view returns (WitnetBytecodes);
    function witnet() external view returns (WitnetRequestBoard);
    
    function defaultRadonSLA() external view returns (WitnetV2.RadonSLA memory);
    
    function estimateUpdateBaseFee(bytes4 feedId, uint256 evmGasPrice, uint256 witEvmPrice) external view returns (uint);
    function estimateUpdateBaseFee(bytes4 feedId, uint256 evmGasPrice, uint256 witEvmPrice, bytes32 slaHash) external view returns (uint);

    function latestResponse(bytes4 feedId) external view returns (Witnet.Response memory);
    function latestResult(bytes4 feedId) external view returns (Witnet.Result memory);

    function latestUpdateQueryId(bytes4 feedId) external view returns (uint256);
    function latestUpdateRequest(bytes4 feedId) external view returns (Witnet.Request memory);
    function latestUpdateResponse(bytes4 feedId) external view returns (Witnet.Response memory);
    function latestUpdateResultError(bytes4 feedId) external view returns (Witnet.ResultError memory);
    function latestUpdateResultStatus(bytes4 feedId) external view returns (Witnet.ResultStatus);

    function lookupBytecode(bytes4 feedId) external view returns (bytes memory);
    function lookupRadHash(bytes4 feedId) external view returns (bytes32);
    function lookupRetrievals(bytes4 feedId) external view returns (WitnetV2.RadonRetrieval[] memory);

    function requestUpdate(bytes4 feedId) external payable returns (uint256 usedFunds);
    function requestUpdate(bytes4 feedId, bytes32 slaHash) external payable returns (uint256 usedFunds);
}