pragma solidity ^0.5.0;

import "./CBOR.sol";

contract Result {
    enum Variant { Ok, Error }

    enum Error {
        RuntimeError,
        InsufficientConsensusError
    }

    Variant variant;
    CBORValue value;
    Error error;

    constructor(bytes memory _value) public {
        value = CBOR.decode(_value);
        // TODO: detect if error, then set variant accordingly
        variant = Variant.Ok;
    }

    function isOk () public view returns(bool) {
        return variant == Variant.Ok;
    }

    function asBytes () public view returns(bytes memory) {
        assert(variant == Variant.Ok);
        return value.asBytes();
    }

    function asUint64 () public view returns(uint64) {
        assert(variant == Variant.Ok);
        return value.asUint64();
    }
}
