pragma solidity ^0.5.0;

contract WitnetBridgeInterface {

    struct DataRequest {
        bytes script;
        bytes result;
        uint256 reward;
    }

    mapping (uint256 => DataRequest) public requests;

    constructor () public
    {
    }

    function post_dr(bytes memory dr, uint256 reward) public returns(uint256 id) {
        id = uint256(keccak256(dr));
        requests[id].script = dr;
        requests[id].result = "";
        requests[id].reward = reward;
        return id;
    }

    function read_dr(uint256 id) public view returns(bytes memory dr) {
        return requests[id].script;
    }

    function report_result (uint256 id, bytes memory result) public {
        requests[id].result = result;       
    }

    function read_result (uint256 id) public view returns(bytes memory result){
        return requests[id].result;
    }
}
