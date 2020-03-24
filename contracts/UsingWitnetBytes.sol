pragma solidity ^0.5.0;

import "./WitnetRequestsBoardProxy.sol";


/**
 * @title The UsingWitnet contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Witnet network
 */
contract UsingWitnetBytes {

  WitnetRequestsBoardProxy wrb;

  /**
  * @notice Include an address to specify the WitnetRequestsBoard
  * @param _wrb WitnetRequestsBoard address
  */
  constructor (address _wrb) public {
    wrb = WitnetRequestsBoardProxy(_wrb);
  }

  /**
  * @notice Include a new Data Request to be resolved by Witnet network
  * @dev Call to `post_dr` function in the WitnetRequestsBoard contract
  * @param _requestBytes Data Request bytes
  * @param _tallyReward Reward specified for the user which post the Data Request result
  * @return Identifier for the Data Request included in the WitnetRequestsBoard
  */
  function witnetPostRequest(bytes memory _requestBytes, uint256 _tallyReward) internal returns(uint256 id) {
    return wrb.postDataRequest.value(msg.value)(_requestBytes, _tallyReward);
  }

  /**
  * @notice Check if a request has been accepted into Witnet
  * @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third
  * parties) before this method returns `true`.
  * @param _id The id of a request that has been previously sent to the WitnetRequestsBoard.
  * @return A boolean telling if the request has been already accepted or not. `false` do not mean rejection, though.
  */
  function witnetCheckRequestAccepted(uint256 _id) internal view returns(bool) {
    // Find the request in the
    uint256 drHash = wrb.readDrHash(_id);
    // If the hash of the data request transaction in Witnet is not the default, then it means that inclusion of the
    // request has been proven to the WRB.
    return drHash != 0;
  }

  /**
  * @notice Upgrade the rewards for a Data Request previously included
  * @dev Call to `upgrade_dr` function in the WitnetRequestsBoard contract
  * @param _id Identifier for the Data Request included in the WitnetRequestsBoard
  * @param _tallyReward Reward specified for the user which post the Data Request result
  */
  function witnetUpgradeRequest(uint256 _id, uint256 _tallyReward) internal {
    wrb.upgradeDataRequest.value(msg.value)(_id, _tallyReward);
  }

  /**
  * @notice Read the result of a resolved Data Request
  * @dev Call to `read_result` function in the WitnetRequestsBoard contract
  * @param _id Identifier for the Data Request included in the WitnetRequestsBoard
  * @return Data Request result
  */
  function witnetReadResult (uint256 _id) internal view returns(bytes memory) {
    return wrb.readResult(_id);
  }
}
