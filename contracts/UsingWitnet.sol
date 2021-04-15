// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;

import "./Request.sol";
import "./Witnet.sol";
import "./WitnetRequestBoardProxy.sol";


/**
 * @title The UsingWitnet contract
 * @notice Contract writers can inherit this contract in order to create Witnet data requests.
 */
contract UsingWitnet {
  using Witnet for Witnet.Result;

  WitnetRequestBoardProxy internal wrb;

 /**
  * @notice Include an address to specify the WitnetRequestBoard.
  * @param _wrb WitnetRequestBoard address.
  */
  constructor(address _wrb) public {
    wrb = WitnetRequestBoardProxy(_wrb);
  }

  // Provides a convenient way for client contracts extending this to block the execution of the main logic of the
  // contract until a particular request has been successfully accepted into Witnet
  modifier witnetRequestAccepted(uint256 _id) {
    require(witnetCheckRequestAccepted(_id), "Witnet request is not yet accepted into the Witnet network");
    _;
  }

  // Ensures that user-specified reward is equal to the total transaction value to prevent users from burning any excess value
  modifier validRewards(uint256 _reward) {
    require(msg.value == _reward, "Transaction value should equal the reward");
    _;
  }

 /**
  * @notice Send a new request to the Witnet network
  * @dev Call to `post_dr` function in the WitnetRequestBoard contract
  * @param _request An instance of the `Request` contract
  * @param _reward The value for rewarding the data request result report.
  * @return Sequencial identifier for the request included in the WitnetRequestBoard
  */
  function witnetPostRequest(Request _request, uint256 _reward)
    internal
    validRewards(_reward)
  returns (uint256)
  {
    return wrb.postDataRequest{value: msg.value}(address(_request), _reward);
  }

 /**
  * @notice Check if a request has been accepted into Witnet.
  * @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third.
  * parties) before this method returns `true`.
  * @param _id The sequential identifier of a request that has been previously sent to the WitnetRequestBoard.
  * @return A boolean telling if the request has been already accepted or not. `false` do not mean rejection, though.
  */
  function witnetCheckRequestAccepted(uint256 _id) internal view returns (bool) {
    // Find the request in the
    uint256 drHash = wrb.readDrHash(_id);
    // If the hash of the data request transaction in Witnet is not the default, then it means that inclusion of the
    // request has been proven to the WRB.
    return drHash != 0;
  }

 /**
  * @notice Upgrade the reward for a Data Request previously included.
  * @dev Call to `upgrade_dr` function in the WitnetRequestBoard contract.
  * @param _id The sequential identifier of a request that has been previously sent to the WitnetRequestBoard.
  * @param _reward The value for rewarding the data request result report.
  */
  function witnetUpgradeRequest(uint256 _id, uint256 _reward)
    internal
    validRewards(_reward)
  {
    wrb.upgradeDataRequest{value: msg.value}(_id, _reward);
  }

 /**
  * @notice Read the result of a resolved request.
  * @dev Call to `read_result` function in the WitnetRequestBoard contract.
  * @param _id The sequential identifier of a request that was posted to Witnet.
  * @return The result of the request as an instance of `Result`.
  */
  function witnetReadResult(uint256 _id) internal view returns (Witnet.Result memory) {
    return Witnet.resultFromCborBytes(wrb.readResult(_id));
  }

 /**
  * @notice Estimate the reward amount.
  * @dev Call to `estimate_gas_cost` function in the WitnetRequestBoard contract.
  * @param _gasPrice The gas price for which we want to retrieve the estimation.
  * @return The reward to be included for the given gas price.
  */
  function witnetEstimateGasCost(uint256 _gasPrice) internal view returns (uint256) {
    return wrb.estimateGasCost(_gasPrice);
  }
}
