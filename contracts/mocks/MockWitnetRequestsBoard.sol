// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../WitnetRequestsBoardInterface.sol";


/**
 * @title Witnet Requests Board mocked
 * @notice Contract to bridge requests to Witnet for testing purposes.
 * @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
  * The result of the requests will be posted back to this contract by the bridge nodes too.
 * @author Witnet Foundation
 */
contract MockWitnetRequestsBoard is WitnetRequestsBoardInterface {

  struct DataRequest {
    address requestAddress;
    uint256 inclusionReward;
    uint256 tallyReward;
    bytes result;
    uint256 timestamp;
    uint256 drHash;
    address payable pkhClaim;
  }

  address public witnet;

  DataRequest[] public requests;

  constructor () public {
    // Insert an empty request so as to initialize the requests array with length > 0
    DataRequest memory request;
    requests.push(request);
    witnet = msg.sender;
  }

  /// @dev Posts a data request into the WRB in expectation that it will be relayed and resolved in Witnet with a total reward that equals to msg.value.
  /// @param _requestAddress The request contract address which includes the request bytecode.
  /// @param _tallyReward The amount of value that will be detracted from the transaction value and reserved for rewarding the reporting of the final result (aka tally) of the data request.
  /// @return The unique identifier of the data request.
  function postDataRequest(address _requestAddress, uint256 _tallyReward)
    external
    payable
    override
  returns(uint256)
  {
    uint256 _id = requests.length;
    DataRequest memory dr;
    requests.push(dr);

    requests[_id].requestAddress = _requestAddress;
    requests[_id].inclusionReward = msg.value - _tallyReward;
    requests[_id].tallyReward = _tallyReward;
    return _id;
  }

  /// @dev Increments the rewards of a data request by adding more value to it. The new request reward will be increased by msg.value minus the difference between the former tally reward and the new tally reward.
  /// @param _id The unique identifier of the data request.
  /// @param _tallyReward The new tally reward. Needs to be equal or greater than the former tally reward.
  function upgradeDataRequest(uint256 _id, uint256 _tallyReward)
    external
    payable
    override
  {
    requests[_id].inclusionReward += msg.value - _tallyReward;
    requests[_id].tallyReward += _tallyReward;
  }

  /// @dev Reports the hash of a data request in Witnet.
  /// @param _id The unique identifier of the data request.
  /// @param _drHash The hash itself.
  function reportDrHash (uint256 _id, uint256 _drHash) external {
    requests[_id].drHash = _drHash;
    msg.sender.transfer(requests[_id].tallyReward);
  }

  /// @dev Reports the result of a data request in Witnet.
  /// @param _id The unique identifier of the data request.
  /// @param _result The result itself as bytes.
  function reportResult (uint256 _id, bytes calldata _result) external {
    requests[_id].result = _result;
    msg.sender.transfer(requests[_id].tallyReward);
  }

  /// @dev Retrieves the result (if already available) of one data request from the WRB.
  /// @param _id The unique identifier of the data request.
  /// @return The result of the DR.
  function readResult (uint256 _id) external view override returns(bytes memory) {
    return requests[_id].result;
  }

  /// @dev Verifies if the contract is upgradable.
  /// @return true if the contract upgradable.
  function isUpgradable(address _address) external view override returns(bool) {
    if (_address == witnet) {
      return true;
    }
    return false;
  }

  /// @dev Retrieves hash of the data request transaction in Witnet.
  /// @param _id The unique identifier of the data request.
  /// @return The hash of the DataRequest transaction in Witnet.
  function readDrHash (uint256 _id) external view override returns(uint256) {
    return requests[_id].drHash;
  }
}
