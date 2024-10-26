// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleEvents {

    event WitOracleCommittee(
        address indexed evmSubscriber,
        Witnet.QueryCapability indexed witCapability,
        Witnet.QueryCapabilityMember[] witCapabilityMembers
    );
    
    /// Emitted every time a new query containing some verified data request is posted to the WitOracle.
    event WitOracleQuery(
        address requester,
        uint256 evmGasPrice,
        uint256 evmReward,
        uint256 queryId, 
        bytes32 queryRadHash,
        Witnet.QuerySLA querySLA
    );

    /// Emitted every time a new query containing some unverified data request bytecode is posted to the WRB.
    event WitOracleQuery(
        address requester,
        uint256 evmGasPrice,
        uint256 evmReward,
        uint256 queryId,
        bytes   queryBytecode,
        Witnet.QuerySLA querySLA
    );

    event WitOracleQueryResponseDispute(
        uint256 queryId,
        address evmResponseDisputer
    );

    /// Emitted when the reward of some not-yet reported query gets upgraded.
    event WitOracleQueryUpgrade(
        uint256 queryId,
        address evmSender,
        uint256 evmGasPrice,
        uint256 evmReward
    );

    /// Emitted when a query with no callback gets reported into the WRB.
    event WitOracleQueryResponse(
        uint256 queryId, 
        uint256 evmGasPrice
    );

    /// Emitted when a query with a callback gets successfully reported into the WRB.
    event WitOracleQueryReponseDelivered(
        uint256 queryId, 
        uint256 evmGasPrice, 
        uint256 evmCallbackGas
    );

    /// Emitted when a query with a callback cannot get reported into the WRB.
    event WitOracleQueryResponseDeliveryFailed(
        uint256 queryId, 
        uint256 evmGasPrice, 
        uint256 evmCallbackActualGas, 
        string  evmCallbackRevertReason,
        bytes   resultCborBytes
    );
}
