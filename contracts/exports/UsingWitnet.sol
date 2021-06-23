// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./IWitnetQuery.sol";
import "./IWitnetRequestor.sol";
import "./WitnetRequest.sol";
import "./WitnetTypes.sol";

/**
 * @title The UsingWitnet contract
 * @notice Contract writers can inherit this contract in order to create Witnet data requests.
 */
abstract contract UsingWitnet {
  address internal immutable witnet;

 /**
  * @notice Include an address to specify the WitnetRequestBoard.
  * @param _wrb WitnetRequestBoard address.
  */
  constructor(address _wrb) {
    witnet = _wrb;
  }

  // Provides a convenient way for client contracts extending this to block the execution of the main logic of the
  // contract until a particular request has been successfully resolved by Witnet
  modifier witnetRequestResolved(uint256 id) {
    require(witnetCheckRequestResolved(id), "Witnet request is not yet resolved by the Witnet network");
    _;
  }

  /**
   * @notice Check if a request has been resolved by Witnet.
   * @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third.
   * parties) before this method returns `true`.
   * @param id The unique identifier of a request that has been previously sent to the WitnetRequestBoard.
   * @return A boolean telling if the request has been already resolved or not.
  **/
  function witnetCheckRequestResolved(uint256 id) internal view returns (bool) {
    // If the result of the data request in Witnet is not the default, then it means that it has been reported as resolved.
    return IWitnetQuery(witnet).readDrTxHash(id) != 0;
  }

  /**
   * @notice Read the result of a resolved Data Request.
   * @param id The unique identifier of a request that was posted to Witnet.
   * @return The result of the request as an instance of `Result`.
  **/
  function witnetDestroyResult(uint256 id) internal returns (WitnetTypes.Result memory) {
    return IWitnetRequestor(witnet).destroyResult(id);
  }

  /**
   * @notice Estimate the reward amount.
   * @dev Call to `estimate_gas_cost` function in the WitnetRequestBoard contract.
   * @param gasPrice The gas price for which we want to retrieve the estimation.
   * @return The reward to be included for the given gas price.
  **/
  function witnetEstimateGasCost(uint256 gasPrice) internal view returns (uint256) {
    return IWitnetRequestor(witnet).estimateGasCost(gasPrice);
  }

  /**
   * @notice Send a new request to the Witnet network with transaction value as result report reward.
   * @param request An instance of the `WitnetRequest` contract.
   * @return Sequencial identifier for the request included in the WitnetRequestBoard.
  **/
  function witnetPostRequest(WitnetRequest request) internal returns (uint256) {
    return IWitnetRequestor(witnet).postDataRequest{value: msg.value}(address(request));
  }

  /**
   * @notice Read the result of a resolved Data Request.
   * @param id The unique identifier of a request that was posted to Witnet.
   * @return The result of the request as an instance of `Result`.
  **/
  function witnetReadResult(uint256 id) internal view returns (WitnetTypes.Result memory) {
    return IWitnetRequestor(witnet).readResult(id);
  }

  /**
   * @notice Upgrade the reward for a Data Request previously included.
   * @param id The unique identifier of a request that has been previously sent to the WitnetRequestBoard.
  **/
  function witnetUpgradeRequest(uint256 id) internal {
    IWitnetRequestor(witnet).upgradeDataRequest{value: msg.value}(id);
  }
}
