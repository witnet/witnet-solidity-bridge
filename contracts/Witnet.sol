pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Buffer.sol";
import "./CBOR.sol";

library Witnet {
  using CBOR for CBOR.Value;
  using Buffer for Buffer.buffer;

  /*
    STRUCTS
  */
  struct Result {
    bool success;
    CBOR.Value cborValue;
  }

  /*
    ENUMS
  */
  enum ErrorCodes {
    RuntimeError,               // The tally script failed during runtime.
    InsufficientConsensusError  // The tally did not fulfill the consensus requirement of the request.
  }

  /*
  Result impl's
  */

  function resultFromCborValue(CBOR.Value memory _cborValue) public pure returns(Result memory) {
    // Witnet uses CBOR tag 39 to represent RADON error code identifiers.
    // [CBOR tag 39] Identifiers for CBOR: https://github.com/lucas-clemente/cbor-specs/blob/master/id.md
    bool success = _cborValue.tag != 39;
    return Result(success, _cborValue);
  }

  function resultFromCborBytes(bytes memory _cborBytes) public pure returns(Result memory) {
    CBOR.Value memory cborValue = CBOR.valueFromBytes(_cborBytes);
    return resultFromCborValue(cborValue);
  }

  /**
   * @notice Tell if a Result is successful
   * @param _result An instance of Result
   * @return `true` if successful, `false` if errored
   */
  function isOk(Result memory _result) public pure returns(bool) {
    return _result.success;
  }

  /**
   * @notice Tell if a Result is errored
   * @param _result An instance of Result
   * @return `true` if errored, `false` if successful
   */
  function isError(Result memory _result) public pure returns(bool) {
    return !_result.success;
  }

  /**
   * @notice Get the raw bytes value of a Result as a `bytes memory` value
   * @param _result An instance of Result
   * @return The `bytes memory` contained in the Result.
   */
  function asBytes(Result memory _result) public pure returns(bytes memory) {
    require(_result.success, "Tried to read bytes value from errored Result");
    return _result.cborValue.buffer.data;
  }

  /**
   * @notice Get the error code of this result as a member of `ErrorCodes`
   * @param _result An instance of Result
   * @return The `CBORValue.Error memory` contained in this result.
   */
  function asError(Result memory _result) public pure returns(ErrorCodes) {
    require(!_result.success, "Tried to read error code from successful Result");
    uint64 errorCode = _result.cborValue.decodeUint64();
    return ErrorCodes(errorCode);
  }

  /**
   * @notice Get the natural numeric value of this result as a `uint64` value
   * @param _result An instance of Result
   * @return The `uint64` contained in this result.
   */
  function asUint64(Result memory _result) public pure returns(uint64) {
    require(_result.success, "Tried to read Uint64 value from errored Result");
    return _result.cborValue.decodeUint64();
  }

}
