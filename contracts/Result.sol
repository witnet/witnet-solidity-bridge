pragma solidity ^0.5.0;

import "./CBOR.sol";

/**
 * @title An algebraic data type comprising two variants (`Ok` and `Error`) that wrap either the value returned by a
 * successful data request or a numeric error code describing what went wrong.
 */
contract Result {
    enum Variant {
        Ok,     // Successful variant. Will contain a value.
        Error   // Errored variant. Will contain an error code.
    }

    enum ErrorCodes {
        RuntimeError,               // The tally script failed during runtime.
        InsufficientConsensusError  // The tally did not fulfill the consensus requirement of the request.
    }

    Variant variant;
    CBORValue value;

    // Any method guarded with this modifier will revert if the result is errored
    modifier onlyIfOk() {
        require(variant == Variant.Ok, "Tried to read the success value of an errored result"); // Revert if not Ok.
        _; // Otherwise (it is Ok), continue.
    }

    // Any method guarded with this modifier will revert if the result is successful
    modifier onlyIfError() {
        require(variant == Variant.Ok, "Tried to read the error value of a successful result"); // Revert if not an Error.
        _; // Otherwise (it is Error), continue.
    }

    // A `Result` is constructed around a `bytes memory` value containing a well-formed CBOR data item.
    constructor(bytes memory _value) public {
        value = CBOR.decode(_value);
        // Witnet uses CBOR tag 39 to represent RADON error code identifiers.
        // [CBOR tag 39] Identifiers for CBOR: https://github.com/lucas-clemente/cbor-specs/blob/master/id.md
        if (value.getTag() == 39) {
            variant = Variant.Error;
        } else {
            variant = Variant.Ok;
        }
    }

    /**
     * @notice Tell if this result is successful
     * @return `true` if successful, `false` if errored
     */
    function isOk () public view returns(bool) {
        return variant == Variant.Ok;
    }

    /**
     * @notice Tell if this result is errored
     * @return `true` if errored, `false` if successful
     */
    function isError () public view returns(bool) {
        return variant == Variant.Error;
    }

    /**
     * @notice Get the raw bytes value of this result as a `bytes memory` value
     * @return The `bytes memory` contained in this result.
     */
    function asBytes () public view onlyIfOk returns(bytes memory) {
        return value.asBytes();
    }

    /**
     * @notice Get the error code of this result as a member of `ErrorCodes`
     * @return The `CBORValue.Error memory` contained in this result.
     */
    function asError () public view onlyIfError returns(ErrorCodes) {
        return ErrorCodes(value.asUint64());
    }

    /**
     * @notice Get the fixed-point decimal numeric value of this result as an `int32` value
     * @return The `int32` contained in this result.
     */
    function asFixed () public view onlyIfOk returns(int32) {
        return value.asFixed();
    }

    /**
     * @notice Get the integer numeric value of this result as an `int128` value
     * @return The `int128` contained in this result.
     */
    function asInt128 () public view onlyIfOk returns(int128) {
        return value.asInt128();
    }

    /**
     * @notice Get the integer numeric value of this result as an `int128` value
     * @return The `int128` contained in this result.
     */
    function asString () public view onlyIfOk returns(string memory) {
        return value.asString();
    }

    /**
     * @notice Get the natural numeric value of this result as a `uint64` value
     * @return The `uint64` contained in this result.
     */
    function asUint64 () public view onlyIfOk returns(uint64) {
        return value.asUint64();
    }

}
