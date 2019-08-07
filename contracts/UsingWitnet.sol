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
    /**
    * @notice Send a new request to the Witnet network
    * @dev Call to `post_dr` function in the WitnetBridgeInterface contract
    * @param _dr An instance of the `Request` contract
    * @param _tallyReward Reward specified for the user which post the request result
    * @return Identifier for the request included in the WitnetBridgeInterface
    */
    function witnetPostRequest(Request _dr, uint256 _tallyReward) public payable returns(uint256 id){
        return wbi.postDataRequest.value(msg.value)(_dr.serialized(), _tallyReward);
    }

    /**
    * @notice Upgrade the rewards for a request previously included
    * @dev Call to `upgrade_dr` function in the WitnetBridgeInterface contract
    * @param _dr The request included in the WitnetBridgeInterface
    * @param _tallyReward Reward specified for the user which post the request result
    */
    function witnetUpgradeRequest(Request _dr, uint256 _tallyReward) public payable {
        wbi.upgradeDataRequest.value(msg.value)(uint256(_dr.id()), _tallyReward);
    }

    /**
    * @notice Read the result of a resolved request
    * @dev Call to `read_result` function in the WitnetBridgeInterface contract
    * @param _dr The request included in the WitnetBridgeInterface
    * @return request result
    */
    function witnetReadResult (Request _dr) public returns(Result){
        return new Result(wbi.readResult(uint256(_dr.id())));
    }
}
