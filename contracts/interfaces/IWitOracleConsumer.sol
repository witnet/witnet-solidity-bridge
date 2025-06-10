// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracle.sol";

interface IWitOracleConsumer {

    /// @notice Accepts a data report from the Wit/oracle blockchain that ought to be
    /// verified by the WitOracle contract pointed out by `witOracle()`. 
    /// @dev The referred `witOracle()` contract emits a `IWitOracle.DataReport` for
    /// every `Witnet.DataPushReport` proven to be authentic. 
    function pushDataReport(Witnet.DataPushReport calldata report, bytes calldata proof) external;
}
