pragma solidity ^0.5.0;

contract WitnetBridgeInterface {
  
  struct DataRequest {
    bytes script;
    bytes result;
    uint256 reward;
  }

  uint256 counter;
  mapping (uint256 => DataRequest) public requests;

  constructor () public
  {
    counter = 0;
  }

  function post_dr(bytes memory dr) public payable returns(uint256 id) {
    id = counter;
    counter++;
    requests[id].script = dr;
    requests[id].result = "";
    requests[id].reward = msg.value;
    return id;
  }

  function read_dr(uint256 id) public view returns(bytes memory dr) {
    return requests[id].script;
  }

  function report_result (uint256 id, bytes memory result) public {
    requests[id].result = result;
    msg.sender.transfer(requests[id].reward);
  }

  function read_result (uint256 id) public view returns(bytes memory result){
    return requests[id].result;
  }
}
