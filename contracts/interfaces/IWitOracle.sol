// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IWitOracleRadonRegistry, Witnet} from "./IWitOracleRadonRegistry.sol";

interface IWitOracle {

    error InvalidDataReport();
    
    event WitOracleReport(
            address indexed evmOrigin, 
            address indexed evmConsumer, 
            address evmReporter,
            Witnet.TransactionHash witDrTxHash,
            Witnet.RadonHash queryRadHash,
            Witnet.QuerySLA  queryParams,
            Witnet.Timestamp resultTimestamp,
            bytes resultCborBytes
        );

    /// @notice Uniquely identifies the WitOracle instance and the chain on which it's deployed.
    function channel() external view returns (bytes4);

    /// @notice Verify the data report (as provided by Wit/Kermit API) is well-formed and authentic,
    /// returning the parsed Witnet.DataResult if so, or reverting otherwise.
    function parseDataReport(Witnet.DataPushReport calldata report, bytes calldata proof) external view returns (Witnet.DataResult memory);

    /// @notice Same as `parseDataReport` but on certain implementations it may store roll-up information 
    /// that will contribute to reduce the cost of verifying and/or rolling-up future data reports.
    /// Emits `DataReport` if report is authentic. 
    function pushDataReport(Witnet.DataPushReport calldata report, bytes calldata proof) external returns (Witnet.DataResult memory);

    /// @notice Returns the WitOracleRadonRegistry in which Witnet-compliant Radon requests
    /// @notice can be formally verified and forever registered as a away to let smart contracts
    /// and users to track actual data sources and offchain computations applied on data updates
    /// safely reported from the Wit/Oracle blockchain. 
    function registry() external view returns (IWitOracleRadonRegistry);
}
