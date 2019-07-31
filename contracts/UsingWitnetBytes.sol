pragma solidity ^0.5.0;

import "./WitnetBridgeInterface.sol";

/**
 * @title The UsingWitnet contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Witnet network
 */
contract UsingWitnetBytes {

  WitnetBridgeInterface wbi;

  /**
  * @notice Include an address to specify the WitnetBridgeInterface
  * @param _wbi WitnetBridgeInterface address
  */
  constructor (address _wbi) public {
    wbi = WitnetBridgeInterface(_wbi);
  }

  /**
  * @notice Include a new Data Request to be resolved by Witnet network
  * @dev Call to `post_dr` function in the WitnetBridgeInterface contract
  * @param _dr Data Request bytes
  * @param _tallyReward Reward specified for the user which post the Data Request result
  * @return Identifier for the Data Request included in the WitnetBridgeInterface
  */
  function witnetPostDataRequest(bytes memory _dr, uint256 _tallyReward) internal returns(uint256 id){
    return wbi.postDataRequest.value(msg.value)(_dr, _tallyReward);
  }

  /**
  * @notice Upgrade the rewards for a Data Request previously included
  * @dev Call to `upgrade_dr` function in the WitnetBridgeInterface contract
  * @param _id Identifier for the Data Request included in the WitnetBridgeInterface
  * @param _tallyReward Reward specified for the user which post the Data Request result
  */
  function witnetUpgradeDataRequest(uint256 _id, uint256 _tallyReward) internal {
    wbi.upgradeDataRequest.value(msg.value)(_id, _tallyReward);
  }

  /**
  * @notice Read the result of a resolved Data Request
  * @dev Call to `read_result` function in the WitnetBridgeInterface contract
  * @param _id Identifier for the Data Request included in the WitnetBridgeInterface
  * @return Data Request result
  */
  function witnetReadResult (uint256 _id) internal view returns(bytes memory){
    return wbi.readResult(_id);
  }
}
