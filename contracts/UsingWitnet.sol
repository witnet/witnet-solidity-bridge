pragma solidity ^0.5.0;

import "./Request.sol";
import "./Witnet.sol";
import "./WitnetBridgeInterface.sol";


/**
 * @title The UsingWitnet contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Witnet network
 */
contract UsingWitnet {
  using Witnet for Witnet.Result;

  WitnetBridgeInterface wbi;

  /**
  * @notice Include an address to specify the WitnetBridgeInterface
  * @param _wbi WitnetBridgeInterface address
  */
  constructor (address _wbi) public {
    wbi = WitnetBridgeInterface(_wbi);
  }

  // Provides a convenient way for client contracts extending this to block the execution of the main logic of the
  // contract until a particular request has been successfully accepted into Witnet
  modifier witnetRequestAccepted(uint256 _id) {
    require(witnetCheckRequestAccepted(_id), "Witnet request is not yet accepted into the Witnet network");
    _;
  }

  /**
  * @notice Send a new request to the Witnet network
  * @dev Call to `post_dr` function in the WitnetBridgeInterface contract
  * @param _request An instance of the `Request` contract
  * @param _requestReward Reward specified for the user which posts the request into Witnet
  * @param _resultReward Reward specified for the user which posts back the request result
  * @return Sequencial identifier for the request included in the WitnetBridgeInterface
  */
  function witnetPostRequest(Request _request, uint256 _requestReward, uint256 _resultReward) internal returns (uint256 id) {
    return wbi.postDataRequest.value(_requestReward + _resultReward)(_request.bytecode(), _resultReward);
  }

  /**
  * @notice Check if a request has been accepted into Witnet
  * @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third
  * parties) before this method returns `true`
  * @param _id The sequential identifier of a request that has been previously sent to the WitnetBridgeInterface
  * @return A boolean telling if the request has been already accepted or not. `false` do not mean rejection, though
  */
  function witnetCheckRequestAccepted(uint256 _id) internal view returns (bool) {
    // Find the request in the
    (,,,,,uint256 drHash,) = wbi.requests(_id);
    // If the hash of the data request transaction in Witnet is not the default, then it means that inclusion of the
    // request has been proven to the WBI.
    return drHash != 0;
  }

  /**
  * @notice Upgrade the rewards for a Data Request previously included
  * @dev Call to `upgrade_dr` function in the WitnetBridgeInterface contract
  * @param _id The sequential identifier of a request that has been previously sent to the WitnetBridgeInterface
  * @param _tallyReward Reward specified for the user which post the Data Request result
  */
  function witnetUpgradeRequest(uint256 _id, uint256 _tallyReward) internal {
    wbi.upgradeDataRequest.value(msg.value)(_id, _tallyReward);
  }

  /**
  * @notice Read the result of a resolved request
  * @dev Call to `read_result` function in the WitnetBridgeInterface contract
  * @param _id The sequential identifier of a request that was posted to Witnet
  * @return The result of the request as an instance of `Result`
  */
  function witnetReadResult(uint256 _id) internal view returns (Witnet.Result memory) {
    return Witnet.resultFromCborBytes(wbi.readResult(_id));
  }
}
