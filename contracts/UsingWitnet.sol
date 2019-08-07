pragma solidity ^0.5.0;

import "./Request.sol";
import "./Result.sol";
import "./UsingWitnetBytes.sol";
import "./WitnetBridgeInterface.sol";

/**
 * @title The UsingWitnetrequest contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Witnet network
 */
contract UsingWitnet is UsingWitnetBytes {
  // Provides a convenient way for client contracts extending this to block the execution of the main logic of the
  // contract until a particular request has been successfully accepted into Witnet.
  modifier witnetRequestAccepted(uint256 _id) {
      require(witnetCheckRequestAccepted(_id));
      _;
  }

  /**
  * @notice Send a new request to the Witnet network
  * @dev Call to `post_dr` function in the WitnetBridgeInterface contract
  * @param _request An instance of the `Request` contract
  * @param _tallyReward Reward specified for the user which post the request result
  * @return Identifier for the request included in the WitnetBridgeInterface
  */
  function witnetPostRequest(Request _request, uint256 _tallyReward) internal returns(uint256 id){
      return witnetPostRequest(_request.serialized(), _tallyReward);
  }

  /**
  * @notice Check if a request has been accepted into Witnet
  * @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third
  * parties) before this method returns `true`.
  * @param _request A request that has been previously sent to the WitnetBridgeInterface.
  * @return A boolean telling if the request has been already accepted or not. `false` do not mean rejection, though.
  */
  function witnetCheckRequestAccepted(Request _request) public view returns(bool){
      return witnetCheckRequestAccepted(_request.id());
  }

  /**
  * @notice Upgrade the rewards for a previously posted request
  * @dev Call to `upgrade_dr` function in the WitnetBridgeInterface contract
  * @param _request A request that has been previously sent to the WitnetBridgeInterface.
  * @param _tallyReward Reward specified for the user which post the request result
  */
  function witnetUpgradeRequest(Request _request, uint256 _tallyReward) internal {
      witnetUpgradeRequest(_request.id(), _tallyReward);
  }

  /**
  * @notice Read the result of a resolved request
  * @dev Call to `read_result` function in the WitnetBridgeInterface contract
  * @param _request A request that was posted to Witnet
  * @return The result of the request as an instance of `Result`
  */
  function witnetReadResult (Request _request) internal returns(Result){
      return new Result(witnetReadResult(_request.id()));
  }
}
