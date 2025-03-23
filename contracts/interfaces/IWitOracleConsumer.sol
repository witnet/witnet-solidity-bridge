// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracle.sol";

interface IWitOracleConsumer {

    function witOracle() external view returns (IWitOracle);

    /// @notice Same as `parseDataReport` but on certain implementations it may store roll-up information 
    /// that will contribute to reduce the cost of verifying and/or rolling-up future data reports.
    /// Emits `DataReport` if report is authentic. 
    function pushDataReport(Witnet.DataPushReport calldata report, bytes calldata proof) external;
}
