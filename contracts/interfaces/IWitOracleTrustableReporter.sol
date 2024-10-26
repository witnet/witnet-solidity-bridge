// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title The Witnet Request Board Reporter interface.
/// @author The Witnet Foundation.
interface IWitOracleTrustableReporter {

    /// @notice Estimates the actual earnings in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    function estimateReportEarnings(
            uint256[] calldata queryIds, 
            bytes calldata evmReportTxMsgData,
            uint256 evmReportTxGasPrice,
            uint256 witEthPrice9
        ) external view returns (uint256 evmRevenues, uint256 evmExpenses);

    /// @notice Retrieves the Witnet Data Request bytecodes and SLAs of previously posted queries.
    /// @dev Returns empty buffer if the query does not exist.
    /// @param queryIds Query identifiers.
    function extractWitnetDataRequests(uint256[] calldata queryIds) 
        external view returns (bytes[] memory drBytecodes);

    /// @notice Reports the Witnet-provided result to a previously posted request. 
    /// @dev Will assume `block.timestamp` as the timestamp at which the request was solved.
    /// @dev Fails if:
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_tallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param queryId The unique identifier of the data request.
    /// @param resultTallyHash The hash of the corresponding data request transaction in Witnet.
    /// @param resultCborBytes The result itself as bytes.
    function reportResult(
            uint256 queryId,
            bytes32 resultTallyHash,
            bytes calldata resultCborBytes
        ) external returns (uint256);

    /// @notice Reports the Witnet-provided result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_tallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param queryId The unique query identifier
    /// @param resultTimestamp The timestamp of the solving tally transaction in Witnet.
    /// @param resultTallyHash The hash of the corresponding data request transaction in Witnet.
    /// @param resultCborBytes The result itself as bytes.
    function reportResult(
            uint256 queryId,
            uint32  resultTimestamp,
            bytes32 resultTallyHash,
            bytes calldata resultCborBytes
        ) external returns (uint256);

    /// @notice Reports Witnet-provided results to multiple requests within a single EVM tx.
    /// @notice Emits either a WitOracleQueryResponse* or a BatchReportError event per batched report.
    /// @dev Fails only if called from unauthorized address.
    /// @param _batchResults Array of BatchResult structs, every one containing:
    ///         - unique query identifier;
    ///         - timestamp of the solving tally txs in Witnet. If zero is provided, EVM-timestamp will be used instead;
    ///         - hash of the corresponding data request tx at the Witnet side-chain level;
    ///         - data request result in raw bytes.
    function reportResultBatch(BatchResult[] calldata _batchResults) external returns (uint256);
        
        struct BatchResult {
            uint256 queryId;
            uint32  resultTimestamp;
            bytes32 resultTallyHash;
            bytes   resultCborBytes;
        }

        event BatchReportError(uint256 queryId, string reason);
}
