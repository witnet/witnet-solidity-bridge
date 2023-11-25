// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IWitnetRequestBoardEvents {
    /// Emitted every time a new query containing some verified data request is posted to the WRB.
    event NewQuery(uint256 indexed id, uint256 evmReward);

    /// Emitted every time a new query containing non-verified data request is posted to the WRB.
    event NewQueryWithBytecode(uint256 indexed id, uint256 evmReward, bytes radBytecode);
    
    /// Emitted when the reward of some not-yet reported query is upgraded.
    event QueryRewardUpgraded(uint256 indexed id, uint256 evmReward);

    /// Emitted when a query with no callback gets reported into the WRB.
    event QueryReport(uint256 indexed id, uint256 evmGasPrice);

    /// Emitted when a query with a callback gets successfully reported into the WRB.
    event QueryCallback(uint256 indexed id, uint256 evmGasPrice, uint256 evmCallbackGas);

    /// Emitted when a query with a callback cannot get reported into the WRB.
    event QueryCallbackRevert(uint256 indexed id, uint256 evmGasPrice, uint256 evmCallbackGas, string evmReason);
}
