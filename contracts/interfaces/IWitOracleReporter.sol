// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title The Witnet Request Board Reporter interface.
/// @author The Witnet Foundation.
interface IWitOracleReporter {

    /// @notice Estimates the actual earnings in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    function estimateReportEarnings(
            uint256[] calldata witnetQueryIds, 
            bytes calldata reportTxMsgData,
            uint256 reportTxGasPrice,
            uint256 nanoWitPrice
        ) external view returns (uint256, uint256);

    /// @notice Retrieves the Witnet Data Request bytecodes and SLAs of previously posted queries.
    /// @dev Returns empty buffer if the query does not exist.
    /// @param queryIds Query identifiers.
    function extractWitnetDataRequests(uint256[] calldata queryIds) 
        external view returns (bytes[] memory drBytecodes);

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
    /// @notice Emits either a WitnetQueryResponse* or a BatchReportError event per batched report.
    /// @dev Fails only if called from unauthorized address.
    /// @param _batchResults Array of BatchResult structs, every one containing:
    ///         - unique query identifier;
    ///         - timestamp of the solving tally txs in Witnet. If zero is provided, EVM-timestamp will be used instead;
    ///         - hash of the corresponding data request tx at the Witnet side-chain level;
    ///         - data request result in raw bytes.
    function reportResultBatch(BatchResult[] calldata _batchResults) external returns (uint256);
        
        struct BatchResult {
            uint256 queryId;
            uint32  queryResultTimestamp;
            bytes32 queryResultTallyHash;
            bytes   queryResultCborBytes;
        }

        event BatchReportError(uint256 queryId, string reason);
}
