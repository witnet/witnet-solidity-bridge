// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleConsumer.sol";

import "../WitOracleRadonRegistry.sol";

interface IWitOracle {

    event DataReport(address evmOrigin, address evmSender, address evmReporter, Witnet.DataResult data);

    /// @notice Uniquely identifies the WitOracle addrees and the chain on which it's deployed.
    function channel() external view returns (bytes4);

    /// @notice Verify the data report (as provided by Wit/Kermit API) is well-formed and authentic,
    /// returning the parsed Witnet.DataResult if so, or reverting otherwise.
    function parseDataReport(bytes calldata report, bytes calldata proof) external view returns (Witnet.DataResult memory);

    /// @notice Same as `parseDataReport` but on certain implementations it may store roll-up information 
    /// that will contribute to reduce the cost of verifying and/or rolling-up future data reports.
    /// Emits `DataReport` if report is authentic. 
    function pushDataReport(bytes calldata report, bytes calldata proof) external returns (Witnet.DataResult memory);
}
