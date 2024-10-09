// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title The Witnet Request Board Reporter trustless interface.
/// @author The Witnet Foundation.
interface IWitOracleReporterTrustless {
    
    event BatchQueryError(uint256 queryId, string reason);
    
    function extractQueryRelayData(uint256 queryId) external view returns (QueryRelayData memory);
    function extractQueryRelayDataBatch(uint256[] calldata queryIds) external view returns (QueryRelayData[] memory);
        struct QueryRelayData  {
            uint256 queryId;
            uint256 queryEvmBlock;
            bytes32 queryEvmHash;
            uint256 queryEvmReward;
            bytes   queryWitDrBytecodes;
            Witnet.RadonSLA queryWitDrSLA;
        }
    
    function claimQueryReward(uint256 queryId) external returns (uint256);
    function claimQueryRewardBatch(uint256[] calldata queryIds) external returns (uint256);
    

    function disputeQueryResponse (uint256 queryId) external returns (uint256);

    function reportQueryResponse(Witnet.QueryResponseReport calldata report) external returns (uint256);
    function reportQueryResponseBatch(Witnet.QueryResponseReport[] calldata reports) external returns (uint256);
    
    function rollupQueryResponseProof(
            Witnet.FastForward[] calldata witOracleRollup, 
            Witnet.QueryResponseReport calldata queryResponseReport, 
            bytes32[] calldata witOracleDdrTalliesProof
        ) external returns (
            uint256 evmTotalReward
        );
    
    function rollupQueryResultProof(
            Witnet.FastForward[] calldata witOracleRollup, 
            Witnet.QueryReport calldata queryReport, 
            bytes32[] calldata witOracleDroTalliesTrie
        ) external returns (
            Witnet.Result memory queryResult
        );
}
