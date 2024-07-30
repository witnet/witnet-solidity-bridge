// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetOracleEvents {
    
    /// Emitted every time a new query containing some verified data request is posted to the WRB.
    event WitnetQuery(
        uint256 id, 
        uint256 evmReward,
        WitnetV2.RadonSLA witnetSLA
    );

    /// Emitted when a query with no callback gets reported into the WRB.
    event WitnetQueryResponse(
        uint256 id, 
        uint256 evmGasPrice
    );

    /// Emitted when a query with a callback gets successfully reported into the WRB.
    event WitnetQueryResponseDelivered(
        uint256 id, 
        uint256 evmGasPrice, 
        uint256 evmCallbackGas
    );

    /// Emitted when a query with a callback cannot get reported into the WRB.
    event WitnetQueryResponseDeliveryFailed(
        uint256 id, 
        bytes   resultCborBytes,
        uint256 evmGasPrice, 
        uint256 evmCallbackActualGas, 
        string  evmCallbackRevertReason
    );

    /// Emitted when the reward of some not-yet reported query is upgraded.
    event WitnetQueryRewardUpgraded(
        uint256 id, 
        uint256 evmReward
    );

}
