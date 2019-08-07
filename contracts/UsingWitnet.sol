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
    modifier witnetRequestAccepted(Request _request) {
        require(witnetCheckRequestAccepted(_request));  // Revert if the data request is not accepted yet.
        _;
    }
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
    * @notice Check if a request has been accepted into Witnet
    * @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third
    * parties) before this method returns `true`.
    * @param _dr A request that has been previously sent to the WitnetBridgeInterface.
    * @return A boolean telling if the request has been already accepted or not. `false` do not mean rejection, though.
    */
    function witnetCheckRequestAccepted(Request _dr) public view returns(bool){
        // Find the request in the
        (,,,,,uint256 drHash,) = wbi.requests(uint256(_dr.id()));
        // If the hash of the data request transaction in Witnet is not the default, then it means that inclusion of the
        // request has been proven to the WBI.
        return drHash != 0;
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
