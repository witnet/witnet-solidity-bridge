pragma solidity ^0.5.0;

import "./BlockRelay.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract WitnetBridgeInterface {

  using SafeMath for uint256;

  struct DataRequest {
    bytes dr;
    uint256 inclusionReward;
    uint256 tallyReward;
    bytes result;
    uint256 timestamp;
    uint256 drHash;
    address payable pkhClaim;
  }

  BlockRelay blockRelay;

  mapping (uint256 => DataRequest) public requests;

  event PostDataRequest(address indexed _from, uint256 _id);
  event InclusionDataRequest(address indexed _from, uint256 _id);
  event PostResult(address indexed _from, uint256 _id);

  constructor (address _blockRelayAddress) public {
    blockRelay = BlockRelay(_blockRelayAddress);
  }

  // @dev Post DR to be resolved by witnet
  /// @param _dr Data request body
  /// @param _tallyReward The quantity from msg.value that is destinated to result posting
  /// @return _id indicating sha256(id)
  function postDataRequest(bytes memory _dr, uint256 _tallyReward) public payable returns(uint256 _id) {
    if (msg.value < _tallyReward){
      revert("You should send a greater amount than the one sent as tally");
    }
    _id = uint256(sha256(_dr));
    if(requests[_id].dr.length != 0) {
      requests[_id].tallyReward += _tallyReward;
      requests[_id].inclusionReward += msg.value - _tallyReward;
      return _id;
    }

    requests[_id].dr = _dr;
    requests[_id].inclusionReward = msg.value - _tallyReward;
    requests[_id].tallyReward = _tallyReward;
    requests[_id].result = "";
    requests[_id].timestamp = 0;
    requests[_id].drHash = 0;
    requests[_id].pkhClaim = address(0);
    emit PostDataRequest(msg.sender, _id);
    return _id;
  }

  // @dev Upgrade DR to be resolved by witnet
  /// @param _id Data request id
  /// @param _tallyReward The quantity from msg.value that is destinated to result posting
  function upgradeDataRequest(uint256 _id, uint256 _tallyReward) public payable {
    // Only allow if not claimed
    requests[_id].inclusionReward += msg.value - _tallyReward;
    requests[_id].tallyReward += _tallyReward;
  }

  // @dev Claim drs to be posted to Witnet by the node
  /// @param _ids Data request ids to be claimed
  /// @param _poe PoE claiming eligibility
  function claimDataRequests(uint256[] memory _ids, bytes memory _poe) public {
    uint256 currentEpoch = block.number;
    uint256 index;
    if(verifyPoe(_poe)){
      for (uint i = 0; i < _ids.length; i++) {
        index = _ids[i];
        if((requests[index].timestamp == 0 || currentEpoch-requests[index].timestamp > 13) &&
        requests[index].drHash==0 &&
        requests[index].result.length==0){
          requests[index].pkhClaim = msg.sender;
          requests[index].timestamp = currentEpoch;
        }
        else{
          revert("One of the DR was already claimed");
        }
      }
    }
  }

  // @dev Report DR inclusion in WBI
  /// @param _id DR id
  /// @param _poi Proof of Inclusion
  /// @param _index The index in the merkle tree
  /// @param _blockHash Block hash in which the DR was included
  function reportDataRequestInclusion (uint256 _id, uint256[] memory _poi, uint256 _index, uint256 _blockHash) public {
    if (requests[_id].drHash == 0){
      uint256 drRoot = blockRelay.readDrMerkleRoot(_blockHash);
      uint256 drHash = uint256(sha256(abi.encodePacked(_id, _poi[0])));
      if (verifyPoi(_poi, drRoot, _index, _id)){
        requests[_id].drHash = drHash;
        requests[_id].pkhClaim.transfer(requests[_id].inclusionReward);
        emit InclusionDataRequest(msg.sender, _id);
      }
    }
  }

  // @dev Report result of DR in WBI
  /// @param _id DR id
  /// @param _poi Proof of Inclusion as a vector of hashes
  /// @param _index The index in the merkle tree
  /// @param _blockHash hash of the block in which the result was inserted
  /// @param _result The actual result
  function reportResult (uint256 _id, uint256[] memory _poi, uint256 _index, uint256 _blockHash, bytes memory _result) public {
    if (requests[_id].drHash!=0 && requests[_id].result.length==0){
      uint256 tallyRoot = blockRelay.readTallyMerkleRoot(_blockHash);
      // this should leave it ready for PoI
      uint256 resHash = uint256(sha256(abi.encodePacked(uint256(sha256(_result)), requests[_id].drHash)));
      if (verifyPoi(_poi, tallyRoot, _index, resHash)){
        requests[_id].result = _result;
        msg.sender.transfer(requests[_id].tallyReward);
        emit PostResult(msg.sender, _id);
      }
    }
  }

  // @dev Read DR from WBI
  /// @param _id DR id
  /// @return The dr
  function readDataRequest (uint256 _id) public view returns(bytes memory){
    return requests[_id].dr;
  }

  // @dev Read result from WBI
  /// @param _id DR id
  /// @return The result of the DR
  function readResult (uint256 _id) public view returns(bytes memory){
    return requests[_id].result;
  }

  function verifyPoe(bytes memory _poe) internal pure returns(bool){
    return true;
  }

  function verifyPoi(uint256[] memory _poi, uint256 _root, uint256 _index, uint256 element) internal pure returns(bool){
    return true;
  }
}
