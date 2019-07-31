pragma solidity ^0.5.0;

import "./Request.sol";
import "./Result.sol";
import "./UsingWitnetBytes.sol";

/**
 * @title The UsingWitnetRequest contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Witnet network
 */
contract UsingWitnetRequest is UsingWitnetBytes {
    /**
    * @notice Include a new Data Request to be resolved by Witnet network
    * @dev Call to `post_dr` function in the WitnetBridgeInterface contract
    * @param _dr Data Request
    * @param _tallyReward Reward specified for the user which post the Data Request result
    * @return Identifier for the Data Request included in the WitnetBridgeInterface
    */
    function witnetPostDataRequest(Request _dr, uint256 _tallyReward) public payable returns(uint256 id){
        return wbi.postDataRequest.value(msg.value)(_dr.serialized(), _tallyReward);
    }

    /**
    * @notice Upgrade the rewards for a Data Request previously included
    * @dev Call to `upgrade_dr` function in the WitnetBridgeInterface contract
    * @param _dr The Data Request included in the WitnetBridgeInterface
    * @param _tallyReward Reward specified for the user which post the Data Request result
    */
    function witnetUpgradeDataRequest(Request _dr, uint256 _tallyReward) public payable {
        wbi.upgradeDataRequest.value(msg.value)(uint256(_dr.id()), _tallyReward);
    }

    /**
    * @notice Read the result of a resolved Data Request
    * @dev Call to `read_result` function in the WitnetBridgeInterface contract
    * @param _dr The Data Request included in the WitnetBridgeInterface
    * @return Data Request result
    */
    function witnetReadResult (Request _dr) public returns(Result){
        return new Result(wbi.readResult(uint256(_dr.id())));
    }
}
