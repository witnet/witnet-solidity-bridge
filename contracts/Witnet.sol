// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "./CBOR.sol";


/**
 * @title A library for decoding Witnet request results
 * @notice The library exposes functions to check the Witnet request success.
 * and retrieve Witnet results from CBOR values into solidity types.
 */
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
    // 0x00: Unknown error. Something went really bad!
    Unknown,
    // Script format errors
    /// 0x01: At least one of the source scripts is not a valid CBOR-encoded value.
    SourceScriptNotCBOR,
    /// 0x02: The CBOR value decoded from a source script is not an Array.
    SourceScriptNotArray,
    /// 0x03: The Array value decoded form a source script is not a valid RADON script.
    SourceScriptNotRADON,
    /// Unallocated
    ScriptFormat0x04,
    ScriptFormat0x05,
    ScriptFormat0x06,
    ScriptFormat0x07,
    ScriptFormat0x08,
    ScriptFormat0x09,
    ScriptFormat0x0A,
    ScriptFormat0x0B,
    ScriptFormat0x0C,
    ScriptFormat0x0D,
    ScriptFormat0x0E,
    ScriptFormat0x0F,
    // Complexity errors
    /// 0x10: The request contains too many sources.
    RequestTooManySources,
    /// 0x11: The script contains too many calls.
    ScriptTooManyCalls,
    /// Unallocated
    Complexity0x12,
    Complexity0x13,
    Complexity0x14,
    Complexity0x15,
    Complexity0x16,
    Complexity0x17,
    Complexity0x18,
    Complexity0x19,
    Complexity0x1A,
    Complexity0x1B,
    Complexity0x1C,
    Complexity0x1D,
    Complexity0x1E,
    Complexity0x1F,
    // Operator errors
    /// 0x20: The operator does not exist.
    UnsupportedOperator,
    /// Unallocated
    Operator0x21,
    Operator0x22,
    Operator0x23,
    Operator0x24,
    Operator0x25,
    Operator0x26,
    Operator0x27,
    Operator0x28,
    Operator0x29,
    Operator0x2A,
    Operator0x2B,
    Operator0x2C,
    Operator0x2D,
    Operator0x2E,
    Operator0x2F,
    // Retrieval-specific errors
    /// 0x30: At least one of the sources could not be retrieved, but returned HTTP error.
    HTTP,
    /// 0x31: Retrieval of at least one of the sources timed out.
    RetrievalTimeout,
    /// Unallocated
    Retrieval0x32,
    Retrieval0x33,
    Retrieval0x34,
    Retrieval0x35,
    Retrieval0x36,
    Retrieval0x37,
    Retrieval0x38,
    Retrieval0x39,
    Retrieval0x3A,
    Retrieval0x3B,
    Retrieval0x3C,
    Retrieval0x3D,
    Retrieval0x3E,
    Retrieval0x3F,
    // Math errors
    /// 0x40: Math operator caused an underflow.
    Underflow,
    /// 0x41: Math operator caused an overflow.
    Overflow,
    /// 0x42: Tried to divide by zero.
    DivisionByZero,
    Size
  }

  /*
  Result impl's
  */

 /**
   * @notice Decode raw CBOR bytes into a Result instance.
   * @param _cborBytes Raw bytes representing a CBOR-encoded value.
   * @return A `Result` instance.
   */
  function resultFromCborBytes(bytes calldata _cborBytes) external pure returns(Result memory) {
    CBOR.Value memory cborValue = CBOR.valueFromBytes(_cborBytes);
    return resultFromCborValue(cborValue);
  }

 /**
   * @notice Decode a CBOR value into a Result instance.
   * @param _cborValue An instance of `CBOR.Value`.
   * @return A `Result` instance.
   */
  function resultFromCborValue(CBOR.Value memory _cborValue) public pure returns(Result memory) {
    // Witnet uses CBOR tag 39 to represent RADON error code identifiers.
    // [CBOR tag 39] Identifiers for CBOR: https://github.com/lucas-clemente/cbor-specs/blob/master/id.md
    bool success = _cborValue.tag != 39;
    return Result(success, _cborValue);
  }

  /**
   * @notice Tell if a Result is successful.
   * @param _result An instance of Result.
   * @return `true` if successful, `false` if errored.
   */
  function isOk(Result memory _result) public pure returns(bool) {
    return _result.success;
  }

  /**
   * @notice Tell if a Result is errored.
   * @param _result An instance of Result.
   * @return `true` if errored, `false` if successful.
   */
  function isError(Result memory _result) public pure returns(bool) {
    return !_result.success;
  }

  /**
   * @notice Decode a bytes value from a Result as a `bytes` value.
   * @param _result An instance of Result.
   * @return The `bytes` decoded from the Result.
   */
  function asBytes(Result memory _result) public pure returns(bytes memory) {
    require(_result.success, "Tried to read bytes value from errored Result");
    return _result.cborValue.decodeBytes();
  }

  /**
   * @notice Decode an error code from a Result as a member of `ErrorCodes`.
   * @param _result An instance of `Result`.
   * @return The `CBORValue.Error memory` decoded from the Result.
   */
  function asErrorCode(Result memory _result) public pure returns(ErrorCodes) {
    uint64[] memory error = asRawError(_result);
    if (error.length == 0) {
      return ErrorCodes.Unknown;
    }

    return supportedErrorOrElseUnknown(error[0]);
  }

  /**
   * @notice Generate a suitable error message for a member of `ErrorCodes` and its corresponding arguments.
   * @dev WARN: Note that client contracts should wrap this function into a try-catch foreseing potential errors generated in this function
   * @param _result An instance of `Result`.
   * @return A tuple containing the `CBORValue.Error memory` decoded from the `Result`, plus a loggable error message.
   */
  function asErrorMessage(Result memory _result) public pure returns(ErrorCodes, string memory) {
    uint64[] memory error = asRawError(_result);
    if (error.length == 0) {
      return (ErrorCodes.Unknown, "Unknown error (no error code)");
    }
    ErrorCodes errorCode = supportedErrorOrElseUnknown(error[0]);
    bytes memory errorMessage;

    if (errorCode == ErrorCodes.SourceScriptNotCBOR && error.length >= 2) {
      errorMessage = abi.encodePacked("Source script #", utoa(error[1]), " was not a valid CBOR value");
    } else if (errorCode == ErrorCodes.SourceScriptNotArray && error.length >= 2) {
      errorMessage = abi.encodePacked("The CBOR value in script #", utoa(error[1]), " was not an Array of calls");
    } else if (errorCode == ErrorCodes.SourceScriptNotRADON && error.length >= 2) {
      errorMessage = abi.encodePacked("The CBOR value in script #", utoa(error[1]), " was not a valid RADON script");
    } else if (errorCode == ErrorCodes.RequestTooManySources && error.length >= 2) {
      errorMessage = abi.encodePacked("The request contained too many sources (", utoa(error[1]), ")");
    } else if (errorCode == ErrorCodes.ScriptTooManyCalls && error.length >= 4) {
      errorMessage = abi.encodePacked(
        "Script #",
        utoa(error[2]),
        " from the ",
        stageName(error[1]),
        " stage contained too many calls (",
        utoa(error[3]),
        ")"
      );
    } else if (errorCode == ErrorCodes.UnsupportedOperator && error.length >= 5) {
      errorMessage = abi.encodePacked(
      "Operator code 0x",
        utohex(error[4]),
        " found at call #",
        utoa(error[3]),
        " in script #",
        utoa(error[2]),
        " from ",
        stageName(error[1]),
        " stage is not supported"
      );
    } else if (errorCode == ErrorCodes.HTTP && error.length >= 3) {
      errorMessage = abi.encodePacked(
        "Source #",
        utoa(error[1]),
        " could not be retrieved. Failed with HTTP error code: ",
        utoa(error[2] / 100),
        utoa(error[2] % 100 / 10),
        utoa(error[2] % 10)
      );
    } else if (errorCode == ErrorCodes.RetrievalTimeout && error.length >= 2) {
      errorMessage = abi.encodePacked(
        "Source #",
        utoa(error[1]),
        " could not be retrieved because of a timeout."
      );
    } else if (errorCode == ErrorCodes.Underflow && error.length >= 5) {
      errorMessage = abi.encodePacked(
        "Underflow at operator code 0x",
        utohex(error[4]),
        " found at call #",
        utoa(error[3]),
        " in script #",
        utoa(error[2]),
        " from ",
        stageName(error[1]),
        " stage"
      );
    } else if (errorCode == ErrorCodes.Overflow && error.length >= 5) {
      errorMessage = abi.encodePacked(
        "Overflow at operator code 0x",
        utohex(error[4]),
        " found at call #",
        utoa(error[3]),
        " in script #",
        utoa(error[2]),
        " from ",
        stageName(error[1]),
        " stage"
      );
    } else if (errorCode == ErrorCodes.DivisionByZero && error.length >= 5) {
      errorMessage = abi.encodePacked(
        "Division by zero at operator code 0x",
        utohex(error[4]),
        " found at call #",
        utoa(error[3]),
        " in script #",
        utoa(error[2]),
        " from ",
        stageName(error[1]),
        " stage"
      );
    } else {
      errorMessage = abi.encodePacked("Unknown error (0x", utohex(error[0]), ")");
    }

    return (errorCode, string(errorMessage));
  }

  /**
   * @notice Decode a raw error from a `Result` as a `uint64[]`.
   * @param _result An instance of `Result`.
   * @return The `uint64[]` raw error as decoded from the `Result`.
   */
  function asRawError(Result memory _result) public pure returns(uint64[] memory) {
    require(!_result.success, "Tried to read error code from successful Result");
    return _result.cborValue.decodeUint64Array();
  }

  /**
   * @notice Decode a fixed16 (half-precision) numeric value from a Result as an `int32` value.
   * @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values.
   * by 5 decimal orders so as to get a fixed precision of 5 decimal positions, which should be OK for most `fixed16`.
   * use cases. In other words, the output of this method is 10,000 times the actual value, encoded into an `int32`.
   * @param _result An instance of Result.
   * @return The `int128` decoded from the Result.
   */
  function asFixed16(Result memory _result) public pure returns(int32) {
    require(_result.success, "Tried to read `fixed16` value from errored Result");
    return _result.cborValue.decodeFixed16();
  }

  /**
   * @notice Decode an array of fixed16 values from a Result as an `int128[]` value.
   * @param _result An instance of Result.
   * @return The `int128[]` decoded from the Result.
   */
  function asFixed16Array(Result memory _result) public pure returns(int128[] memory) {
    require(_result.success, "Tried to read `fixed16[]` value from errored Result");
    return _result.cborValue.decodeFixed16Array();
  }

  /**
   * @notice Decode a integer numeric value from a Result as an `int128` value.
   * @param _result An instance of Result.
   * @return The `int128` decoded from the Result.
   */
  function asInt128(Result memory _result) public pure returns(int128) {
    require(_result.success, "Tried to read `int128` value from errored Result");
    return _result.cborValue.decodeInt128();
  }

  /**
   * @notice Decode an array of integer numeric values from a Result as an `int128[]` value.
   * @param _result An instance of Result.
   * @return The `int128[]` decoded from the Result.
   */
  function asInt128Array(Result memory _result) public pure returns(int128[] memory) {
    require(_result.success, "Tried to read `int128[]` value from errored Result");
    return _result.cborValue.decodeInt128Array();
  }

  /**
   * @notice Decode a string value from a Result as a `string` value.
   * @param _result An instance of Result.
   * @return The `string` decoded from the Result.
   */
  function asString(Result memory _result) public pure returns(string memory) {
    require(_result.success, "Tried to read `string` value from errored Result");
    return _result.cborValue.decodeString();
  }

  /**
   * @notice Decode an array of string values from a Result as a `string[]` value.
   * @param _result An instance of Result.
   * @return The `string[]` decoded from the Result.
   */
  function asStringArray(Result memory _result) public pure returns(string[] memory) {
    require(_result.success, "Tried to read `string[]` value from errored Result");
    return _result.cborValue.decodeStringArray();
  }

  /**
   * @notice Decode a natural numeric value from a Result as a `uint64` value.
   * @param _result An instance of Result.
   * @return The `uint64` decoded from the Result.
   */
  function asUint64(Result memory _result) public pure returns(uint64) {
    require(_result.success, "Tried to read `uint64` value from errored Result");
    return _result.cborValue.decodeUint64();
  }

  /**
   * @notice Decode an array of natural numeric values from a Result as a `uint64[]` value.
   * @param _result An instance of Result.
   * @return The `uint64[]` decoded from the Result.
   */
  function asUint64Array(Result memory _result) public pure returns(uint64[] memory) {
    require(_result.success, "Tried to read `uint64[]` value from errored Result");
    return _result.cborValue.decodeUint64Array();
  }

  /**
   * @notice Convert a stage index number into the name of the matching Witnet request stage.
   * @param _stageIndex A `uint64` identifying the index of one of the Witnet request stages.
   * @return The name of the matching stage.
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
  * @notice Get an `ErrorCodes` item from its `uint64` discriminant, or default to `ErrorCodes.Unknown` if it doesn't
  * exist.
  * @param _discriminant The numeric identifier of an error.
  * @return A member of `ErrorCodes`.
  */
  function supportedErrorOrElseUnknown(uint64 _discriminant) private pure returns(ErrorCodes) {
    if (_discriminant < uint8(ErrorCodes.Size)) {
      return ErrorCodes(_discriminant);
    } else {
      return ErrorCodes.Unknown;
    }
  }

  /**
   * @notice Convert a `uint64` into a 1, 2 or 3 characters long `string` representing its.
   * three less significant decimal values.
   * @param _u A `uint64` value.
   * @return The `string` representing its decimal value.
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

  /**
 * @notice Convert a `uint64` into a 2 characters long `string` representing its two less significant hexadecimal values.
 * @param _u A `uint64` value.
 * @return The `string` representing its hexadecimal value.
 */
  function utohex(uint64 _u) private pure returns(string memory) {
    bytes memory b2 = new bytes(2);
    uint8 d0 = uint8(_u / 16) + 48;
    uint8 d1 = uint8(_u % 16) + 48;
    if (d0 > 57)
      d0 += 7;
    if (d1 > 57)
      d1 += 7;
    b2[0] = byte(d0);
    b2[1] = byte(d1);
    return string(b2);
  }
}
