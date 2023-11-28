// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title The Witnet Request Board Reporter interface.
/// @author The Witnet Foundation.
interface IWitnetRequestBoardReporter {

    /// @notice Reports the Witnet-provided result to a previously posted request. 
    /// @dev Will assume `block.timestamp` as the timestamp at which the request was solved.
    /// @dev Fails if:
    /// @dev - the `_witnetQueryId` is not in 'Posted' status.
    /// @dev - provided `_tallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param witnetQueryId The unique identifier of the data request.
    /// @param witnetResultTallyHash The hash of the corresponding data request transaction in Witnet.
    /// @param witnetResultCborBytes The result itself as bytes.
    function reportResult(
            uint256 witnetQueryId,
            bytes32 witnetResultTallyHash,
            bytes calldata witnetResultCborBytes
        ) external returns (uint256);

    /// @notice Reports the Witnet-provided result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_witnetQueryId` is not in 'Posted' status.
    /// @dev - provided `_tallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param witnetQueryId The unique query identifier
    /// @param witnetResultTimestamp The timestamp of the solving tally transaction in Witnet.
    /// @param witnetResultTallyHash The hash of the corresponding data request transaction in Witnet.
    /// @param witnetResultCborBytes The result itself as bytes.
    function reportResult(
            uint256 witnetQueryId,
            uint64  witnetResultTimestamp,
            bytes32 witnetResultTallyHash,
            bytes calldata witnetResultCborBytes
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
            uint64  timestamp;
            bytes32 tallyHash;
            bytes   cborBytes;
        }

        event BatchReportError(uint256 queryId, string reason);
}
