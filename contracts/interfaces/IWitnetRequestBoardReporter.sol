// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title The Witnet Request Board Reporter interface.
/// @author The Witnet Foundation.
interface IWitnetRequestBoardReporter {

    /// @notice Estimates the actual earnings (or loss), in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    /// @dev Fails if the query does not exist, or if deleted.
    function estimateQueryEarnings(uint256[] calldata queryIds, uint256 gasPrice) external view returns (int256);

    /// @notice Reports the Witnet-provided result to a previously posted request. 
    /// @dev Will assume `block.timestamp` as the timestamp at which the request was solved.
    /// @dev Fails if:
    /// @dev - the `_witnetQueryId` is not in 'Posted' status.
    /// @dev - provided `_tallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param witnetQueryId The unique identifier of the data request.
    /// @param witnetQueryResultTallyHash The hash of the corresponding data request transaction in Witnet.
    /// @param witnetQueryResultCborBytes The result itself as bytes.
    function reportResult(
            uint256 witnetQueryId,
            bytes32 witnetQueryResultTallyHash,
            bytes calldata witnetQueryResultCborBytes
        ) external returns (uint256);

    /// @notice Reports the Witnet-provided result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_witnetQueryId` is not in 'Posted' status.
    /// @dev - provided `_tallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param witnetQueryId The unique query identifier
    /// @param witnetQueryResultTimestamp The timestamp of the solving tally transaction in Witnet.
    /// @param witnetQueryResultTallyHash The hash of the corresponding data request transaction in Witnet.
    /// @param witnetQueryResultCborBytes The result itself as bytes.
    function reportResult(
            uint256 witnetQueryId,
            uint32  witnetQueryResultTimestamp,
            bytes32 witnetQueryResultTallyHash,
            bytes calldata witnetQueryResultCborBytes
        ) external returns (uint256);

    /// @notice Reports Witnet-provided results to multiple requests within a single EVM tx.
    /// @dev Must emit a PostedResult event for every succesfully reported result.
    /// @param _batchResults Array of BatchResult structs, every one containing:
    ///         - unique query identifier;
    ///         - timestamp of the solving tally txs in Witnet. If zero is provided, EVM-timestamp will be used instead;
    ///         - hash of the corresponding data request tx at the Witnet side-chain level;
    ///         - data request result in raw bytes.
    /// @param _verbose If true, must emit a BatchReportError event for every failing report, if any. 
    function reportResultBatch(BatchResult[] calldata _batchResults, bool _verbose) external returns (uint256);
        
        struct BatchResult {
            uint256 queryId;
            uint32  queryResultTimestamp;
            bytes32 queryResultTallyHash;
            bytes   queryResultCborBytes;
        }

        event BatchReportError(uint256 queryId, string reason);
}
