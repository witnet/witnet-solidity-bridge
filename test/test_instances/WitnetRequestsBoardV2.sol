pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "vrf-solidity/contracts/VRF.sol";
import "../../contracts/ActiveBridgeSetLib.sol";
import "block-relay/contracts/BlockRelayProxy.sol";
import "../../contracts/WitnetRequestsBoardInterface.sol";


/**
 * @title Witnet Requests Board
 * @notice Contract to bridge requests to Witnet
 * @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network
  * The result of the requests will be posted back to this contract by the bridge nodes too.
 * @author Witnet Foundation
 */
contract WitnetRequestsBoardV2 is WitnetRequestsBoardInterface {

  using SafeMath for uint256;
  using ActiveBridgeSetLib for ActiveBridgeSetLib.ActiveBridgeSet;

  struct DataRequest {
    bytes dr;
    uint256 inclusionReward;
    uint256 tallyReward;
    bytes result;
    uint256 timestamp;
    uint256 drHash;
    address payable pkhClaim;
  }

  BlockRelayProxy blockRelay;

  DataRequest[] public requests;

  ActiveBridgeSetLib.ActiveBridgeSet abs;

  address witnet;

  // Replication factor for Active Bridge Set identities
  uint8 repFactor;

  // Event emitted when a new DR is posted
  event PostedRequest(address indexed _from, uint256 _id);

  // Event emitted when a DR inclusion proof is posted
  event IncludedRequest(address indexed _from, uint256 _id);

  // Event emitted when a result proof is posted
  event PostedResult(address indexed _from, uint256 _id);

  constructor (address _blockRelayAddress, uint8 _repFactor) public {
    blockRelay = BlockRelayProxy(_blockRelayAddress);
    witnet = msg.sender;

    // Insert an empty request so as to initialize the requests array with length > 0
    DataRequest memory request;
    requests.push(request);
    repFactor = _repFactor;
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
    uint256 _id = requests.length;
    DataRequest memory dr;
    requests.push(dr);

    requests[_id].dr = _dr;
    requests[_id].inclusionReward = msg.value - _tallyReward;
    requests[_id].tallyReward = _tallyReward;
    requests[_id].result = "";
    requests[_id].timestamp = 0;
    requests[_id].drHash = 0;
    requests[_id].pkhClaim = address(0);
    emit PostedRequest(msg.sender, _id);
    return _id;
  }

  /// @dev Increments the rewards of a data request by adding more value to it. The new request reward will be increased by msg.value minus the difference between the former tally reward and the new tally reward.
  /// @param _id The unique identifier of the data request.
  /// @param _tallyReward The new tally reward. Needs to be equal or greater than the former tally reward.
  function upgradeDataRequest(uint256 _id, uint256 _tallyReward)
    external
    payable
  {
    requests[_id].inclusionReward += msg.value - _tallyReward;
    requests[_id].tallyReward += _tallyReward;
  }

  /// @dev Retrieves the result (if already available) of one data request from the WRB.
  /// @param _id The unique identifier of the data request.
  /// @return The result of the DR
  function readResult (uint256 _id) external view returns(bytes memory) {
    return requests[_id].result;
  }

   /// @dev Verifies if the contract is upgradable
  /// @return true if the contract upgradable
  function isUpgradable(address _address) external view returns(bool) {
    return false;
  }

}
