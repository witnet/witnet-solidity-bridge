// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracle.sol";

interface IWitOracleConsumer {

    /// @notice Process the outcome of some oracle query allegedly solved in Witnet,
    /// that ought to be verified by the Wit/Oracle contract pointed out by `witOracle()`. 
    /// The Wit/Oracle contract will emit a full `IWitOracle.WitOracleReport` event,
    /// only if the `report` is proven to be valid and authentic.
    /// @dev Reverts if the report is proven to be corrupted. 
    function pushDataReport(Witnet.DataPushReport calldata report, bytes calldata proof) external;

    /// @notice Returns the address of the Wit/Oracle bridge that will be used to verify pushed data reports.
    function witOracle() external view returns (address);
}
