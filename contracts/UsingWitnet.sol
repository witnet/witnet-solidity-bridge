// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libs/Witnet.sol";
import "./interfaces/WitnetRequestBoardInterface.sol";

/// @title The UsingWitnet contract
/// @dev Contract writers can inherit this contract in order to create Witnet data requests. 
/// @author The Witnet Foundation.
abstract contract UsingWitnet {
  WitnetRequestBoardInterface internal immutable _WRB;

  /// @notice Include an address to specify the WitnetRequestBoard.
  /// @param _wrb WitnetRequestBoard address.
  constructor(address _wrb) {
    require(_wrb != address(0), "UsingWitnet: null contract");
    _WRB = WitnetRequestBoardInterface(_wrb);
  }

  /// Provides a convenient way for client contracts extending this to block the execution of the main logic of the
  /// contract until a particular request has been successfully resolved by Witnet
  modifier witnetRequestResolved(uint256 _id) {
    require(witnetCheckRequestResolved(_id), "Witnet request is not yet resolved by the Witnet network");
    _;
  }

  /// @notice Check if a request has been resolved by Witnet.
  /// @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third.
  /// parties) before this method returns `true`.
  /// @param _id The unique identifier of a request that has been previously sent to the WitnetRequestBoard.
  /// @return A boolean telling if the request has been already resolved or not. Returns `false` if called after destroying the result (i.e. `destroyResult(uint256 _id).
  function witnetCheckRequestResolved(uint256 _id) internal view returns (bool) {
    // If the result of the data request in Witnet is not the default, then it means that it has been reported as resolved.
    return _WRB.readDrTxHash(_id) != 0;
  }

  /// @notice Retrieves result of previously posted DR, and removes it from storage.
  /// @param _id The unique identifier of a previously posted data request.
  /// @return The result of the DR
  function witnetDestroyResult(uint256 _id) internal returns (WitnetData.Result memory) {
    return Witnet.resultFromCborBytes(_WRB.destroyResult(_id));
  }

  /// @notice Estimate the reward amount.
  /// @param _gasPrice The gas price for which we want to retrieve the estimation.
  /// @return The reward to be included for the given gas price.
  function witnetEstimateGasCost(uint256 _gasPrice) internal view returns (uint256) {
    return _WRB.estimateGasCost(_gasPrice);
  }

  /// @notice Send a new request to the Witnet network with transaction value as result report reward.
  /// @param _request An instance of the `WitnetRequest` contract.
  /// @return Sequencial identifier for the request included in the WitnetRequestBoard.
  function witnetPostRequest(WitnetRequest _request) internal returns (uint256) {
    return _WRB.postDataRequest{value: msg.value}(address(_request));
  }

  /// @notice Read the result of a resolved request.
  /// @param _id The unique identifier of a request that was posted to Witnet.
  /// @return The result of the request as an instance of `Result`.
  function witnetReadResult(uint256 _id) internal view returns (WitnetData.Result memory) {
    return Witnet.resultFromCborBytes(_WRB.readResult(_id));
  } 

  /// @notice Upgrade the reward for a Data Request previously included.
  /// @dev Call to `upgrade_dr` function in the WitnetRequestBoard contract.
  /// @param _id The unique identifier of a request that has been previously sent to the WitnetRequestBoard.
  function witnetUpgradeRequest(uint256 _id) internal {
    _WRB.upgradeDataRequest{value: msg.value}(_id);
  }
}
