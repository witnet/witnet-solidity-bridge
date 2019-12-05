pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./BufferLib.sol";
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
    // Unknown error. Something went really bad!
    Unknown,
    // Script format errors
    /// At least one of the source scripts is not a valid CBOR-encoded value.
    SourceScriptNotCBOR,
    /// The CBOR value decoded from a source script is not an Array.
    SourceScriptNotArray,
    /// The Array value decoded form a source script is not a valid RADON script.
    SourceScriptNotRADON,
    // Complexity errors
    /// The request contains too many sources.
    RequestTooManySources,
    /// The script contains too many calls.
    ScriptTooManyCalls,
    // Operator errors
    /// The operator does not exist.
    UnsupportedOperator,
    // Retrieval-specific errors
    /// At least one of the sources could not be retrieved, but returned HTTP error.
    HTTP,
    // Math errors
    /// Math operator caused an underflow.
    Underflow,
    /// Math operator caused an overflow.
    Overflow,
    /// Tried to divide by zero.
    DivisionByZero,
    // The tally script failed during runtime.
    RuntimeError,
    // The tally did not fulfill the consensus requirement of the request.
    InsufficientConsensusError,
    // This is not a real error but a way to mark the size of the `enum`
    Size
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
   * @param _result An instance of `Result`
   * @return The `CBORValue.Error memory` decoded from the Result
   */
  function asErrorCode(Result memory _result) public pure returns(ErrorCodes) {
    uint64[] memory error = asRawError(_result);

    // Decode the error code only if it belongs to the `ErrorCodes` enum — otherwise, default to `ErrorCodes.Unknown`
    if (error[0] <= uint8(ErrorCodes.Size)) {
      return ErrorCodes(error[0]);
    } else {
      return ErrorCodes.Unknown;
    }
  }

  /**
   * @notice Generate a suitable error message for a member of `ErrorCodes` and its corresponding arguments
   * @param _result An instance of `Result`
   * @return A tuple containing the `CBORValue.Error memory` decoded from the `Result`, plus a loggable error message.
   */
  function asErrorMessage(Result memory _result) public pure returns(ErrorCodes, string memory) {
    uint64[] memory error = asRawError(_result);
    ErrorCodes errorCode;
    bytes memory errorMessage;

    // Decode the error code only if it belongs to the `ErrorCodes` enum — otherwise, default to `ErrorCodes.Unknown`
    if (error[0] <= uint8(ErrorCodes.Size)) {
      errorCode = ErrorCodes(error[0]);
    } else {
      errorCode = ErrorCodes.Unknown;
    }

    if (errorCode == ErrorCodes.SourceScriptNotCBOR) {
      errorMessage = abi.encodePacked("Source script #", utoa(error[1]), " was not a valid CBOR value");
    } else if (errorCode == ErrorCodes.SourceScriptNotArray) {
      errorMessage = abi.encodePacked("The CBOR value in script #", utoa(error[1]), " was not an Array of calls");
    } else if (errorCode == ErrorCodes.SourceScriptNotRADON) {
      errorMessage = abi.encodePacked("The CBOR value in script #", utoa(error[1]), " was not a valid RADON script");
    } else if (errorCode == ErrorCodes.RequestTooManySources) {
      errorMessage = abi.encodePacked("The request contained too many sources (", utoa(error[1]), ")");
    } else if (errorCode == ErrorCodes.ScriptTooManyCalls) {
      errorMessage = abi.encodePacked("Script #", utoa(error[2]), " from the ", stageName(error[1]), " stage contained too many calls (", utoa(error[3]), ")");
    } else if (errorCode == ErrorCodes.UnsupportedOperator) {
      errorMessage = abi.encodePacked("Operator code ", utoa(error[4]), " found at call #", utoa(error[3]), " in script #", utoa(error[2]), " from ", stageName(error[1]), " stage is not supported");
    } else if (errorCode == ErrorCodes.HTTP) {
      errorMessage = abi.encodePacked("Source #", utoa(error[1]), " could not be retrieved. Failed with HTTP error code: ", utoa(error[2] / 100), utoa(error[2] % 100 / 10), utoa(error[2] % 10));
    } else if (errorCode == ErrorCodes.Underflow) {
      errorMessage = abi.encodePacked("Underflow at operator code ", utoa(error[4]), " found at call #", utoa(error[3]), " in script #", utoa(error[2]), " from ", stageName(error[1]), " stage");
    } else if (errorCode == ErrorCodes.Overflow) {
      errorMessage = abi.encodePacked("Overflow at operator code ", utoa(error[4]), " found at call #", utoa(error[3]), " in script #", utoa(error[2]), " from ", stageName(error[1]), " stage");
    } else if (errorCode == ErrorCodes.DivisionByZero) {
      errorMessage = abi.encodePacked("Division by zero at operator code ", utoa(error[4]), " found at call #", utoa(error[3]), " in script #", utoa(error[2]), " from ", stageName(error[1]), " stage");
    } else if (errorCode == ErrorCodes.RuntimeError) {
      errorMessage = abi.encodePacked("Unspecified runtime error at operator code ", utoa(error[4]), " found at call #", utoa(error[3]), " in script #", utoa(error[2]), " from ", stageName(error[1]), " stage");
    } else if (errorCode == ErrorCodes.InsufficientConsensusError) {
      errorMessage = abi.encodePacked("Insufficient consensus. Required: ", utoa(error[1]), ". Achieved: ", utoa(error[2]));
    } else {
      errorMessage = abi.encodePacked("Unknown error (", utoa(error[0]), ")");
    }

    return (errorCode, string(errorMessage));
  }

  /**
   * @notice Decode a raw error from a `Result` as a `uint64[]`
   * @param _result An instance of `Result`
   * @return The `uint64[]` raw error as decoded from the `Result`
   */
  function asRawError(Result memory _result) public pure returns(uint64[] memory) {
    require(!_result.success, "Tried to read error code from successful Result");
    return _result.cborValue.decodeUint64Array();
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

  /**
   * @notice Convert a stage index number into the name of the matching Witnet request stage
   * @param _stageIndex A `uint64` identifying the index of one of the Witnet request stages
   * @return The name of the matching stage
   */
  function stageName(uint64 _stageIndex) public pure returns(string memory) {
    if (_stageIndex == 0) {
      return "retrieval";
    } else if (_stageIndex == 1) {
      return "aggregation";
    } else if (_stageIndex == 2) {
      return "tally";
    } else {
      return "unknown";
    }
  }

  /**
   * @notice Convert a `uint8` into a 1, 2 or 3 characters long `string` representing its decimal value
   * @param _u A `uint8` value
   * @return The `string` representing its decimal value
   */
  function utoa(uint64 _u) private pure returns(string memory) {
    if (_u < 10) {
      bytes memory b1 = new bytes(1);
      b1[0] = byte(uint8(_u) + 48);
      return string(b1);
    } else if (_u < 100) {
      bytes memory b2 = new bytes(2);
      b2[0] = byte(uint8(_u / 10) + 48);
      b2[1] = byte(uint8(_u % 10) + 48);
      return string(b2);
    } else {
      bytes memory b3 = new bytes(3);
      b3[0] = byte(uint8(_u / 100) + 48);
      b3[1] = byte(uint8(_u % 100 / 10) + 48);
      b3[2] = byte(uint8(_u % 10) + 48);
      return string(b3);
    }
  }
}
