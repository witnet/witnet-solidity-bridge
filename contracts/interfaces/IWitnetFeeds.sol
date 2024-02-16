// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitnetOracle.sol";
import "../WitnetRequestBytecodes.sol";

interface IWitnetFeeds {

    event DeletedFeed       (address indexed from, bytes4 indexed feedId, string caption);
    event SettledFeed       (address indexed from, bytes4 indexed feedId, string caption, bytes32 radHash);
    event SettledFeedSolver (address indexed from, bytes4 indexed feedId, string caption, address solver);
    event SettledRadonSLA   (address indexed from, WitnetV2.RadonSLA sla);
    
    event UpdateRequest(
            address indexed   origin, 
            bytes4 indexed    feedId, 
            uint256           witnetQueryId, 
            uint256           witnetQueryEvmReward, 
            WitnetV2.RadonSLA witnetQuerySLA
        );
    
    event UpdateRequestReward(
            address indexed origin, 
            bytes4 indexed  feedId, 
            uint256         witnetQueryId, 
            uint256         witnetQueryReward
        );
    
    function dataType() external view returns (Witnet.RadonDataTypes);
    function prefix() external view returns (string memory);
    function registry() external view returns (WitnetRequestBytecodes);
    function witnet() external view returns (WitnetOracle);
    
    function defaultRadonSLA() external view returns (Witnet.RadonSLA memory);
    function estimateUpdateBaseFee(uint256 evmGasPrice) external view returns (uint);

    function lastValidResponse(bytes4 feedId) external view returns (WitnetV2.Response memory);

    function latestUpdateQueryId(bytes4 feedId) external view returns (uint256);
    function latestUpdateRequest(bytes4 feedId) external view returns (WitnetV2.Request memory);
    function latestUpdateResponse(bytes4 feedId) external view returns (WitnetV2.Response memory);
    function latestUpdateResponseStatus(bytes4 feedId) external view returns (WitnetV2.ResponseStatus);
    function latestUpdateResultError(bytes4 feedId) external view returns (Witnet.ResultError memory);
    
    function lookupWitnetBytecode(bytes4 feedId) external view returns (bytes memory);
    function lookupWitnetRadHash(bytes4 feedId) external view returns (bytes32);
    function lookupWitnetRetrievals(bytes4 feedId) external view returns (Witnet.RadonRetrieval[] memory);

    function requestUpdate(bytes4 feedId) external payable returns (uint256 usedFunds);
    function requestUpdate(bytes4 feedId, WitnetV2.RadonSLA calldata updateSLA) external payable returns (uint256 usedFunds);
}