// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./IWitnetRequestCallback.sol";

/// @title Witnet Requestor Interface
/// @notice It defines how to interact with the Witnet Request Board in order to:
///   - request the execution of Witnet Radon scripts (data request);
///   - upgrade the resolution reward of any previously posted request, in case gas price raises in mainnet;
///   - read the result of any previously posted request, eventually reported by the Witnet DON.
///   - remove from storage all data related to past and solved data requests, and results.
/// @author The Witnet Foundation.
interface IWitnetRequestBoardV2 {

    event PostedQuery(address indexed from, bytes32 hash, address callback);
    event DeletedQuery(address indexed from, bytes32 hash);
    event ReportedQuery(address indexed from, bytes32 hash, address callback);
    event DisputedQuery(address indexed from, bytes32 hash, bytes32 tallyHash);

    function DDR_QUERY_TAG() external view returns (bytes4);
    function DDR_REPORT_QUERY_GAS_BASE() external view returns (uint256);
    function DDR_REPORT_QUERY_MIN_STAKE_WEI() external view returns (uint256);
    function DDR_REPORT_QUERY_MIN_STAKE_WEI(uint256 gasPrice) external view returns (uint256);

    function class() external view returns (bytes4);

    function estimateQueryReward(
            bytes32 radHash, 
            WitnetV2.RadonSLAv2 calldata slaParams,
            uint256 nanoWitWeiEvmPrice,
            uint256 weiEvmMaxGasPrice,
            uint256 evmCallbackGasLimit
        ) external view returns (uint256);

    function readQueryBridgeData(bytes32 queryHash)
        external view returns (
            WitnetV2.QueryStatus status,
            uint256 weiEvmReward,
            uint256 weiEvmStake,
            bytes memory radBytecode,
            WitnetV2.RadonSLAv2 memory slaParams
        );   
    
    function readQueryBridgeStatus(bytes32 queryHash)
        external view returns (
            WitnetV2.QueryStatus status,
            uint256 weiEvmReward
        );

    function readQuery(bytes32 queryHash) external view returns (WitnetV2.Query memory);
    function readQueryEvmReward(bytes32 queryHash) external view returns (uint256);
    function readQueryCallback(bytes32 queryHash) external view returns (WitnetV2.QueryCallback memory);
    function readQueryRequest(bytes32 queryHash) external view returns (bytes32 radHash, WitnetV2.RadonSLAv2 memory sla);
    function readQueryReport(bytes32 queryHash) external view returns (WitnetV2.QueryReport memory);
    function readQueryResult(bytes32 queryHash) external view returns (Witnet.Result memory);

    function checkQueryStatus(bytes32 queryHash) external view returns (WitnetV2.QueryStatus);
    function checkQueryResultStatus(bytes32 queryHash) external view returns (Witnet.ResultStatus);
    function checkQueryResultError(bytes32 queryHash) external view returns (Witnet.ResultError memory); 

    function postQuery(
            bytes32 radHash, 
            WitnetV2.RadonSLAv2 calldata slaParams
        ) external payable returns (bytes32 queryHash);
    
    function postQuery(
            bytes32 radHash,
            WitnetV2.RadonSLAv2 calldata slaParams,
            IWitnetRequestCallback callback,
            uint256 callbackGas
        ) external payable returns (bytes32 queryHash);
    
    function reportQuery(bytes32 queryHash, bytes calldata relayerSignature, WitnetV2.QueryReport memory) external;
    function reportQueryBatch(bytes32[] calldata hashes, bytes[] calldata signatures, WitnetV2.QueryReport[] calldata) external;

    function disputeQuery(bytes32 queryHash, WitnetV2.QueryReport memory) external;

    function claimQueryReward(bytes32 queryHash) external returns (uint256);
    function deleteQuery(bytes32 queryHash) external;    

    function determineQueryTallyHash(bytes32 queryTallyHash) external returns (bytes32 queryHash, uint256 queryStakes);
}