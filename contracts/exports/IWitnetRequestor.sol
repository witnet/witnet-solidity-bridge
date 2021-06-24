// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetTypes.sol";

/**
  * @title Interface for posting and retrieving DRs to/from Witnet mainnet.
  * @author Witnet Foundation
 */
interface IWitnetRequestor {

  /// @notice Event emitted when a new DR is posted.
  event PostedRequest(uint256 id, address from);

  /// @notice Event emitted when a solved DR gets destroyed.
  event DestroyedRequest(uint256 id, address from);

  /// @dev Retrieves result of previously posted DR, and removes it from storage.
  /// @param id The unique identifier of a previously posted data request.
  /// @return The result of the DR.
  function destroyResult(uint256 id) external returns (WitnetTypes.Result memory);

  /// @dev Estimate the amount of reward we need to insert for a given gas price.
  /// @param gasPrice The gas price for which we need to calculate the rewards.
  /// @return The reward to be included for the given gas price.
  function estimateGasCost(uint256 gasPrice) external view returns (uint256);

  /// @dev Posts a data request into the WRB in expectation that it will be relayed 
  /// @dev and resolved in Witnet with a total reward that equals to msg.value.
  /// @param witnetRequest The Witnet request contract address which provides actual RADON bytecode.
  /// @return The unique identifier of the posted DR.
  function postDataRequest(address witnetRequest) external payable returns (uint256);

    /// @dev Retrieves the result (if already available) of one data request from the WRB.
  /// @param id The unique identifier of the data request.
  /// @return The result of the DR
  function readResult(uint256 id) external view returns (WitnetTypes.Result memory);

  /// @dev Increments the reward of a data request by adding the transaction value to it.
  /// @param id The unique identifier of the data request.
  function upgradeDataRequest(uint256 id) external payable;  

}
