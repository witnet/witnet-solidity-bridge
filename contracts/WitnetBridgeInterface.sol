pragma solidity ^0.5.0;

contract WitnetBridgeInterface {

  struct DataRequest {
    bytes dr;
    uint256 inclusion_reward;
    uint256 tallie_reward;
    bytes result;
    uint256 timestamp;
    uint256 dr_hash;
    address payable pkh_claim;
  }

  mapping (uint256 => DataRequest) public requests;

  event PostDataRequest(address indexed _from, uint256);
  event InclusionDataRequest(address indexed _from, uint256 id);
  event PostResult(address indexed _from, uint256 id);

  // @dev Post DR to be resolved by witnet
  /// @param dr Data request body
  /// @param tallie_reward The quantity from msg.value that is destinated to result posting
  /// @return id indicating sha256(id)
  function post_dr(bytes memory dr, uint256 tallie_reward) public payable returns(uint256 id) {
    if (msg.value < tallie_reward){
      revert("You should send a greater amount than the one sent as tallie");
    }
    id = uint256(sha256(dr));
    if(requests[id].dr.length != 0) {
      requests[id].tallie_reward += tallie_reward;
      requests[id].inclusion_reward += msg.value - tallie_reward;
      return id;
    }

    requests[id].dr = dr;
    requests[id].inclusion_reward = msg.value - tallie_reward;
    requests[id].tallie_reward = tallie_reward;
    requests[id].result = "";
    requests[id].timestamp = 0;
    requests[id].dr_hash = 0;
    requests[id].pkh_claim = address(0);
    emit PostDataRequest(msg.sender, id);
    return id;
  }

  // @dev Upgrade DR to be resolved by witnet
  /// @param id Data request id
  /// @param tallie_reward The quantity from msg.value that is destinated to result posting
  function upgrade_dr(uint256 id, uint256 tallie_reward) public payable {
    // Only allow if not claimed
    requests[id].inclusion_reward += msg.value - tallie_reward;
    requests[id].tallie_reward += tallie_reward;
  }

  // @dev Claim drs to be posted to Witnet by the node
  /// @param ids Data request ids to be claimed
  /// @param PoE PoE claiming eligibility
  function claim_drs(uint256[] memory ids, bytes memory PoE) public {
    uint256 current_epoch = block.number;
    // PoE pleaseee
    uint256 index;
    for (uint i = 0; i < ids.length; i++) {
      index = ids[i];
      if((requests[index].timestamp == 0 || current_epoch-requests[index].timestamp > 13) &&
      requests[index].dr_hash==0 &&
      requests[index].result.length==0){
        requests[index].pkh_claim = msg.sender;
        requests[index].timestamp = current_epoch;
      }
      else{
        revert("One of the DR was already claimed. Espabila");
      }
    }
  }
  // @dev Report DR inclusion in WBI
  /// @param id DR id
  /// @param poi Proof of Inclusion
  /// @param block_hash Block hash in which the DR was included
  function report_dr_inclusion (uint256 id, bytes memory poi, uint256 block_hash) public {
    if (requests[id].dr_hash == 0){
      if (verify_poi(poi)){
        // This should be equal to tx_hash, derived from sha256(dr, dr_rest) (PoI[0])
        requests[id].dr_hash = block_hash;
        requests[id].pkh_claim.transfer(requests[id].inclusion_reward);
      }
    }
    emit InclusionDataRequest(msg.sender, id);
  }

  // @dev Report result of DR in WBI
  /// @param id DR id
  /// @param poi Proof of Inclusion
  /// @param block_hash hash of the block in which the result was inserted
  /// @param result The actual result
  function report_result (uint256 id, bytes memory poi, uint256 block_hash, bytes memory result) public {
    if (requests[id].dr_hash!=0 && requests[id].result.length==0){
      if (verify_poi(poi)){
        requests[id].result = result;
        msg.sender.transfer(requests[id].tallie_reward);
        emit PostResult(msg.sender, id);
      }
    }
  }

  // @dev Read DR from WBI
  /// @param id DR id
  /// @return The dr
  function read_dr (uint256 id) public view returns(bytes memory){
    return requests[id].dr;
  }

  // @dev Read result from WBI
  /// @param id DR id
  /// @return The result of the DR
  function read_result (uint256 id) public view returns(bytes memory){
    return requests[id].result;
  }

  function verify_poe(bytes memory poe) internal pure returns(bool){
    return true;
  }
  function verify_poi(bytes memory poi) internal pure returns(bool){
    return true;
  }
}
