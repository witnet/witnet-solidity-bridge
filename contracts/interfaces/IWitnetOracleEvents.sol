// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../libs/WitnetV2.sol";

interface IWitnetOracleEvents {
    
    /// Emitted every time a new query containing some verified data request is posted to the WRB.
    event WitnetQuery(
        uint256 indexed id, 
        uint256 evmReward,
        WitnetV2.RadonSLA witSLA
    );

    /// Emitted when a query with no callback gets reported into the WRB.
    event WitnetQueryReported(uint256 indexed id, uint256 evmGasPrice);

    /// Emitted when the reward of some not-yet reported query is upgraded.
    event WitnetQueryRewardUpgraded(uint256 indexed id, uint256 evmReward);

    /// Emitted when a query with a callback gets successfully reported into the WRB.
    event WitnetResponseDelivered(uint256 indexed id, uint256 evmGasPrice, uint256 evmCallbackGas);

    /// Emitted when a query with a callback cannot get reported into the WRB.
    event WitnetResponseDeliveryFailed(
            uint256 indexed id, 
            bytes   resultCborBytes,
            uint256 evmGasPrice, 
            uint256 evmCallbackGas, 
            string  evmCallbackRevertReason
        );
}
