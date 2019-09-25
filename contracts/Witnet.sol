pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Buffer.sol";
import "./CBOR.sol";


library Witnet {
  using CBOR for CBOR.Value;

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
   * @notice Decode a bytes value from a Result as a `bytes` value
   * @param _result An instance of Result
   * @return The `bytes` decoded from the Result.
   */
  function asBytes(Result memory _result) public pure returns(bytes memory) {
    require(_result.success, "Tried to read bytes value from errored Result");
    return _result.cborValue.decodeBytes();
  }

  /**
   * @notice Decode an error code from a Result as a member of `ErrorCodes`
   * @param _result An instance of Result
   * @return The `CBORValue.Error memory` decoded from the Result
   */
  function asError(Result memory _result) public pure returns(ErrorCodes) {
    require(!_result.success, "Tried to read error code from successful Result");
    uint64 errorCode = _result.cborValue.decodeUint64();
    return ErrorCodes(errorCode);
  }

  /**
   * @notice Decode a fixed16 (half-precision) numeric value from a Result as an `int32` value
   * @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values
   * by 5 decimal orders so as to get a fixed precision of 5 decimal positions, which should be OK for most `fixed16`
   * use cases. In other words, the output of this method is 10,000 times the actual value, encoded into an `int32`.
   * @param _result An instance of Result
   * @return The `int128` decoded from the Result
   */
  function asFixed16(Result memory _result) public pure returns(int32) {
    require(_result.success, "Tried to read `fixed16` value from errored Result");
    return _result.cborValue.decodeFixed16();
  }

  /**
   * @notice Decode an array of fixed16 values from a Result as an `int128[]` value
   * @param _result An instance of Result
   * @return The `int128[]` decoded from the Result
   */
  function asFixed16Array(Result memory _result) public pure returns(int128[] memory) {
    require(_result.success, "Tried to read `fixed16[]` value from errored Result");
    return _result.cborValue.decodeFixed16Array();
  }

  /**
   * @notice Decode a integer numeric value from a Result as an `int128` value
   * @param _result An instance of Result
   * @return The `int128` decoded from the Result
   */
  function asInt128(Result memory _result) public pure returns(int128) {
    require(_result.success, "Tried to read `int128` value from errored Result");
    return _result.cborValue.decodeInt128();
  }

  /**
   * @notice Decode an array of integer numeric values from a Result as an `int128[]` value
   * @param _result An instance of Result
   * @return The `int128[]` decoded from the Result
   */
  function asInt128Array(Result memory _result) public pure returns(int128[] memory) {
    require(_result.success, "Tried to read `int128[]` value from errored Result");
    return _result.cborValue.decodeInt128Array();
  }

  /**
   * @notice Decode a string value from a Result as a `string` value
   * @param _result An instance of Result
   * @return The `string` decoded from the Result
   */
  function asString(Result memory _result) public pure returns(string memory) {
    require(_result.success, "Tried to read `string` value from errored Result");
    return _result.cborValue.decodeString();
  }

  /**
  * @notice Decode an array of string values from a Result as a `string[]` value
  * @param _result An instance of Result
  * @return The `string[]` decoded from the Result
  */
  function asStringArray(Result memory _result) public pure returns(string[] memory) {
    require(_result.success, "Tried to read `string[]` value from errored Result");
    return _result.cborValue.decodeStringArray();
  }

  /**
   * @notice Decode a natural numeric value from a Result as a `uint64` value
   * @param _result An instance of Result
   * @return The `uint64` decoded from the Result
   */
  function asUint64(Result memory _result) public pure returns(uint64) {
    require(_result.success, "Tried to read `uint64` value from errored Result");
    return _result.cborValue.decodeUint64();
  }

  /**
 * @notice Decode an array of natural numeric values from a Result as a `uint64[]` value
 * @param _result An instance of Result
 * @return The `uint64[]` decoded from the Result
 */
  function asUint64Array(Result memory _result) public pure returns(uint64[] memory) {
    require(_result.success, "Tried to read `uint64[]` value from errored Result");
    return _result.cborValue.decodeUint64Array();
  }

}
