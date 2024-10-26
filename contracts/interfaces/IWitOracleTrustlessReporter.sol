// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title The Witnet Request Board Reporter trustless interface.
/// @author The Witnet Foundation.
interface IWitOracleTrustlessReporter {
    
    event BatchQueryError(Witnet.QueryId queryId, string reason);
    
    function extractDataRequest(Witnet.QueryId queryId) external view returns (DataRequest memory);
    function extractDataRequestBatch(Witnet.QueryId[] calldata queryIds) external view returns (DataRequest[] memory);
        
        struct DataRequest  {
            Witnet.QueryId queryId;
            Witnet.QueryHash queryHash;
            Witnet.QueryReward queryReward;
            bytes radonBytecode;
            RadonSLAv21 radonSLA;
        }
        
        struct RadonSLAv21 {
            Witnet.QuerySLA params;
            Witnet.QueryCapabilityMember[] members;
        }
    
    function claimQueryReward(Witnet.QueryId queryId) external returns (uint256);
    function claimQueryRewardBatch(Witnet.QueryId[] calldata queryIds) external returns (uint256);
    
    function disputeQueryResponse (Witnet.QueryId queryId) external returns (uint256);

    function reportQueryResponse(Witnet.DataPullReport calldata report) external returns (uint256);
    function reportQueryResponseBatch(Witnet.DataPullReport[] calldata reports) external returns (uint256);
    
    function rollupQueryResponseProof(
            Witnet.FastForward[] calldata witOracleRollup, 
            Witnet.DataPullReport calldata queryResponseReport, 
            bytes32[] calldata witOracleDdrTalliesProof
        ) external returns (
            uint256 evmTotalReward
        );    
}
