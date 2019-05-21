pragma solidity ^0.5.0;

contract WitnetBridgeInterface {

    struct DataRequest {
        bytes script;
        bytes result;
    }

    mapping (uint256 => DataRequest) public requests;

    constructor () public
    {
    }

    function post_dr(bytes memory dr, uint256 post_reward, uint256 report_reward) public returns(uint256 id) {
        id = uint256(keccak256(dr));
        requests[id].script = dr;
        requests[id].result = "";
        return id;
    }

    function read_dr(uint256 id) public view returns(bytes memory dr) {
        return requests[id].script;
    }

    /*function upgrade_reward(uint256 id, uint256 post_reward, uint256 report_reward) public {
    }

    function claim_drs(uint256[] memory ids, bytes memory poe) public {}

    function claim_post_reward(uint256 id, bytes memory poi, uint256 block_number) public {}

    function report_result (uint256 id, bytes memory poi, bytes memory poe, uint256 block_number, bytes memory result) public {}

    function read_result (uint256 id) public view {}*/
}
