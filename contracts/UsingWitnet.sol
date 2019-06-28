pragma solidity ^0.5.0;

import "./WitnetBridgeInterface.sol";



/**
 * @title The UsingWitnet contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Witnet network
 */
contract UsingWitnet{

    WitnetBridgeInterface wbi;

    /**
    * @notice Include an address to specify the WitnetBridgeInterface
    * @param _wbi WitnetBridgeInterface address
    */
    // TODO: Remove this constructor to allow to child contracts define
    // its own constructor and use another way to include the WBI address
    constructor (address _wbi) public {
        wbi = WitnetBridgeInterface(_wbi);
    }

    /**
     * @notice Include a new Data Request to be resolved by Witnet network
     * @dev Call to `post_dr` function in the WitnetBridgeInterface contract
     * @param _dr Data Request bytes
     * @param _tallie_reward Reward specified for the user which post the Data Request result
     * @return Identifier for the Data Request included in the WitnetBridgeInterface
     */
    function witnetPostDataRequest(bytes memory _dr, uint256 _tallie_reward) public payable returns(uint256 id){
        return wbi.postDataRequest.value(msg.value)(_dr, _tallie_reward);
    }

    /**
     * @notice Upgrade the rewards for a Data Request previously included
     * @dev Call to `upgrade_dr` function in the WitnetBridgeInterface contract
     * @param _id Identifier for the Data Request included in the WitnetBridgeInterface
     * @param _tallie_reward Reward specified for the user which post the Data Request result
     */
    function witnetUpgradeDataRequest(uint256 _id, uint256 _tallie_reward) public payable {
        wbi.upgradeDataRequest.value(msg.value)(_id, _tallie_reward);
    }

    /**
     * @notice Read the result of a resolved Data Request
     * @dev Call to `read_result` function in the WitnetBridgeInterface contract
     * @param _id Identifier for the Data Request included in the WitnetBridgeInterface
     * @return Data Request result
     */
    function witnetReadResult (uint256 _id) public view returns(bytes memory){
        return wbi.readResult(_id);
    }
}
