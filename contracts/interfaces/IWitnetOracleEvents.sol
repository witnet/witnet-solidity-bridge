// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetOracleEvents {
    
    /// Emitted every time a new query containing some verified data request is posted to the WitnetOracle.
    event WitnetQuery(
        address evmRequester,
        uint256 evmGasPrice,
        uint256 evmReward,
        uint256 queryId, 
        bytes32 queryRadHash,
        Witnet.RadonSLA querySLA
    );

    /// Emitted every time a new query containing some unverified data request bytecode is posted to the WRB.
    event WitnetQuery(
        address evmRequester,
        uint256 evmGasPrice,
        uint256 evmReward,
        uint256 queryId,
        bytes   queryBytecode,
        Witnet.RadonSLA querySLA
    );

    /// Emitted when the reward of some not-yet reported query gets upgraded.
    event WitnetQueryUpgrade(
        uint256 queryId,
        address evmSender,
        address evmGasPrice,
        uint256 evmReward
    );

    /// Emitted when a query with no callback gets reported into the WRB.
    event WitnetQueryResponse(
        uint256 queryId, 
        uint256 evmGasPrice
    );

    /// Emitted when a query with a callback gets successfully reported into the WRB.
    event WitnetQueryResponseDelivered(
        uint256 queryId, 
        uint256 evmGasPrice, 
        uint256 evmCallbackGas
    );

    /// Emitted when a query with a callback cannot get reported into the WRB.
    event WitnetQueryResponseDeliveryFailed(
        uint256 queryId, 
        uint256 evmGasPrice, 
        uint256 evmCallbackActualGas, 
        string  evmCallbackRevertReason,
        bytes   resultCborBytes
    );
}
