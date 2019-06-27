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
  uint256[] available_drs;

  event PostDataRequest(address indexed _from, uint256);
  event InclusionDataRequest(address indexed _from, uint256 id);
  event PostResult(address indexed _from, uint256 id);

  function post_dr(bytes memory dr, uint256 tallie_reward) public payable returns(uint256 id) {
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
    available_drs.push(id);
    emit PostDataRequest(msg.sender, id);
    return id;
  }

  function upgrade_dr(uint256 id, uint256 tallie_reward) public payable {
    // Only allow if not claimed
    requests[id].inclusion_reward += msg.value - tallie_reward;
    requests[id].tallie_reward += tallie_reward;
  }
  // max_value to be passed to make sure the claimer has enough money to perform the action
  function claim_drs(uint256[] memory ids, bytes memory PoE) public {
    uint256 current_epoch = block.number;
    // PoE pleaseee
    for (uint i = 0; i < ids.length; i++) {
      if((requests[i].timestamp == 0 || current_epoch-requests[i].timestamp > 13) &&
      requests[i].dr_hash==0 &&
      requests[i].result.length==0){
        requests[i].pkh_claim = msg.sender;
        requests[i].timestamp = current_epoch;
      }
      else{
        revert("One of the DR was already claimed. Espabila");
      }
    }
  }

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

  function report_result (uint256 id, bytes memory result) public {
    if (requests[id].dr_hash!=0 && requests[id].result.length==0){
      requests[id].result = result;
      msg.sender.transfer(requests[id].tallie_reward);
      emit PostResult(msg.sender, id);
    }
  }

  function read_dr (uint256 id) public view returns(bytes memory){
    return requests[id].dr;
  }

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
