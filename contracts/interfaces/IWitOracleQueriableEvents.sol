// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleQueriableEvents {

    /// Emitted every time a new query containing some verified data request is posted to the WitOracle.
    event WitOracleQuery(
        address indexed evmRequester,
        uint256 evmGasPrice,
        uint256 evmReward,
        Witnet.QueryId queryId, 
        Witnet.RadonHash radonHash,
        Witnet.QuerySLA radonParams
    );

    /// Emitted when the reward of some not-yet reported query gets upgraded.
    event WitOracleQueryUpgrade(
        Witnet.QueryId queryId,
        address evmSender,
        uint256 evmGasPrice,
        uint256 evmReward
    );


    /// Emitted when a query with no callback gets reported into the WRB.
    event WitOracleQueryReport(
        Witnet.QueryId queryId, 
        uint256 evmGasPrice
    );

    event WitOracleQueryReportDispute(
        Witnet.QueryId queryId,
        address evmDisputer
    );

    /// Emitted when a query with a callback gets successfully reported into the WRB.
    event WitOracleQueryReportDelivery(
        Witnet.QueryId queryId, 
        address evmConsumer,
        uint256 evmGasPrice, 
        uint256 evmCallbackGas
    );

    /// Emitted when a query with a callback cannot get reported into the WRB.
    event WitOracleResportDeliveryFailed(
        Witnet.QueryId queryId, 
        address evmConsumer,
        uint256 evmGasPrice, 
        uint256 evmCallbackActualGas, 
        string  evmCallbackRevertReason,
        bytes   resultCborBytes
    );
}
