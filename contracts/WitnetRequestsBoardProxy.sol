pragma solidity ^0.5.0;

import "./WitnetRequestsBoardInterface.sol";


/**
 * @title Block Relay Proxy
 * @notice Contract to act as a proxy between the Witnet Bridge Interface and the block relay
 * @dev More information can be found here
 * DISCLAIMER: this is a work in progress, meaning the contract could be voulnerable to attacks
 * @author Witnet Foundation
 */
contract WitnetRequestsBoardProxy {

  address public witnetRequestsBoardAddress;
  WitnetRequestsBoardInterface witnetRequestsBoardInstance;
  // Last id of the WRB controller
  uint256 currentLastId;

  // Struct if the information of each controller
  struct ControllerInfo {
    address controllerAddress;
    uint256 lastId;
    uint256 offset;
  }

  // Array with the controllers that have been used in the Proxy
  ControllerInfo[] controllers;

  modifier notIdentical(address _newAddress) {
    require(_newAddress != witnetRequestsBoardAddress, "The provided Witnet Requests Board instance address is already in use");
    _;
  }

  constructor(address _witnetRequestsBoardAddress) public {
    // Initialize the first epoch pointing to the first controller
    controllers.push(ControllerInfo({controllerAddress: _witnetRequestsBoardAddress, lastId: 0, offset: 0}));
    witnetRequestsBoardAddress = _witnetRequestsBoardAddress;
    witnetRequestsBoardInstance = WitnetRequestsBoardInterface(_witnetRequestsBoardAddress);
  }

  /// @dev Posts a data request into the WRB in expectation that it will be relayed and resolved in Witnet with a total reward that equals to msg.value.
  /// @param _dr The bytes corresponding to the Protocol Buffers serialization of the data request output.
  /// @param _tallyReward The amount of value that will be detracted from the transaction value and reserved for rewarding the reporting of the final result (aka tally) of the data request.
  /// @return The unique identifier of the data request.
  function postDataRequest(bytes calldata _dr, uint256 _tallyReward)
    external
    payable
    returns(uint256)
  {
    uint256 n = controllers.length;
    uint256 offset = controllers[n - 1].offset;
    //Update the currentLastId with the id in the controller plus the offSet
    currentLastId = witnetRequestsBoardInstance.postDataRequest(_dr, _tallyReward) + offset;
    return currentLastId;
  }

  /// @dev Increments the rewards of a data request by adding more value to it. The new request reward will be increased by msg.value minus the difference between the former tally reward and the new tally reward.
  /// @param _id The unique identifier of the data request.
  /// @param _tallyReward The new tally reward. Needs to be equal or greater than the former tally reward.
  function upgradeDataRequest(uint256 _id, uint256 _tallyReward)
    external
    payable
  {
    address wrbAddress;
    uint256 offSetWrb;
    (wrbAddress, offSetWrb) = getController(_id);
    return witnetRequestsBoardInstance.upgradeDataRequest(_id - offSetWrb, _tallyReward);
  }

  /// @dev Retrieves the result (if already available) of one data request from the WRB.
  /// @param _id The unique identifier of the data request.
  /// @return The result of the DR
  function readResult (uint256 _id)
    external
    returns(bytes memory)
  {
    // Get the address and the offset of the corresponding to id
    address wrbAddress;
    uint256 offSetWrb;
    (wrbAddress, offSetWrb) = getController(_id);
    // Return the result of the DR readed in the corresponding Controller with its own id
    WitnetRequestsBoardInterface wrbWithResult;
    wrbWithResult = WitnetRequestsBoardInterface(wrbAddress);
    return wrbWithResult.readResult(_id - offSetWrb);
  }

  /// @notice Upgrades the Witnet Requests Board if the current one is upgradeable
  /// @param _newAddress address of the new block relay to upgrade
  function upgradeWitnetRequestsBoard(address _newAddress) public notIdentical(_newAddress) {
    // Require the WRB is upgradable
    require(witnetRequestsBoardInstance.isUpgradable(msg.sender), "The upgrade has been rejected by the current implementation");
    // Set the offSet for the next WRB
    uint256 n = controllers.length;
    // Map the currentLastId to the corresponding witnetRequestsBoardAddress and add it to controllers
    // controllers.push(ControllerInfo({controllerAddress: _newAddress, lastId: currentLastId, offset: controllers[n - 1].lastId}));
    controllers.push(ControllerInfo({controllerAddress: witnetRequestsBoardAddress, lastId: currentLastId, offset: controllers[n - 1].lastId}));
    // Upgrade the WRB
    witnetRequestsBoardAddress = _newAddress;
    witnetRequestsBoardInstance = WitnetRequestsBoardInterface(_newAddress);
  }

  /// @notice Gets the controller from an Id
  /// @param _id id of a Data Request from which we get the controller
  function getController(uint256 _id) internal returns(address _controllerAddress, uint256 _offset) {
    uint256 n = controllers.length;
    // If the id is bigger than the lastId of the previous Controller, read the result in the current Controller
    for (uint i = n; i > 0; i--) {
      if (_id >= controllers[i-1].lastId) {
        return (controllers[i-1].controllerAddress, controllers[i-1].offset);
      }
    }
  }

}

