pragma solidity ^0.5.0;

contract Request {
    bytes public serialized;
    bytes32 public id;

    constructor(bytes memory _serialized) public {
        serialized = _serialized;
        id = sha256(_serialized);
    }
}
