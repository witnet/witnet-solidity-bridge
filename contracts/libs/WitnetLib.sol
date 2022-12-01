// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetV2.sol";

/// @title A library for decoding Witnet request results
/// @notice The library exposes functions to check the Witnet request success.
/// and retrieve Witnet results from CBOR values into solidity types.
/// @author The Witnet Foundation.
library WitnetLib {

    using WitnetBuffer for WitnetBuffer.Buffer;
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];
    using WitnetLib for bytes;

    /// ===============================================================================================================
    /// --- WitnetLib internal methods --------------------------------------------------------------------------------

    function size(WitnetV2.RadonDataTypes _type) internal pure returns (uint) {
        if (_type == WitnetV2.RadonDataTypes.Integer
            || _type == WitnetV2.RadonDataTypes.Float
        ) {
            return 9;
        } else if (_type == WitnetV2.RadonDataTypes.Bool) {
            return 1;
        } else {
            // undetermined
            return 0; 
        }
    }

    function toAddress(bytes memory _value) internal pure returns (address) {
        return address(toBytes20(_value));
    }

    function toBytes4(bytes memory _value) internal pure returns (bytes4) {
        return bytes4(toFixedBytes(_value, 4));
    }
    
    function toBytes20(bytes memory _value) internal pure returns (bytes20) {
        return bytes20(toFixedBytes(_value, 20));
    }
    
    function toBytes32(bytes memory _value) internal pure returns (bytes32) {
        return toFixedBytes(_value, 32);
    }

    function toFixedBytes(bytes memory _value, uint8 _numBytes)
        internal pure
        returns (bytes32 _bytes32)
    {
        assert(_numBytes <= 32);
        unchecked {
            uint _len = _value.length > _numBytes ? _numBytes : _value.length;
            for (uint _i = 0; _i < _len; _i ++) {
                _bytes32 |= bytes32(_value[_i] & 0xff) >> (_i * 8);
            }
        }
    }

    /// @notice Convert a `uint64` into a 2 characters long `string` representing its two less significant hexadecimal values.
    /// @param _u A `uint64` value.
    /// @return The `string` representing its hexadecimal value.
    function toHexString(uint8 _u)
        internal pure
        returns (string memory)
    {
        bytes memory b2 = new bytes(2);
        uint8 d0 = uint8(_u / 16) + 48;
        uint8 d1 = uint8(_u % 16) + 48;
        if (d0 > 57)
            d0 += 7;
        if (d1 > 57)
            d1 += 7;
        b2[0] = bytes1(d0);
        b2[1] = bytes1(d1);
        return string(b2);
    }

    /// @notice Convert a `uint64` into a 1, 2 or 3 characters long `string` representing its.
    /// three less significant decimal values.
    /// @param _u A `uint64` value.
    /// @return The `string` representing its decimal value.
    function toString(uint8 _u)
        internal pure
        returns (string memory)
    {
        if (_u < 10) {
            bytes memory b1 = new bytes(1);
            b1[0] = bytes1(uint8(_u) + 48);
            return string(b1);
        } else if (_u < 100) {
            bytes memory b2 = new bytes(2);
            b2[0] = bytes1(uint8(_u / 10) + 48);
            b2[1] = bytes1(uint8(_u % 10) + 48);
            return string(b2);
        } else {
            bytes memory b3 = new bytes(3);
            b3[0] = bytes1(uint8(_u / 100) + 48);
            b3[1] = bytes1(uint8(_u % 100 / 10) + 48);
            b3[2] = bytes1(uint8(_u % 10) + 48);
            return string(b3);
        }
    }

    /// @notice Returns true if Witnet.Result contains an error.
    /// @param _result An instance of Witnet.Result.
    /// @return `true` if errored, `false` if successful.
    function failed(Witnet.Result memory _result)
      internal pure
      returns (bool)
    {
        return !_result.success;
    }

    /// @notice Returns true if Witnet.Result contains valid result.
    /// @param _result An instance of Witnet.Result.
    /// @return `true` if errored, `false` if successful.
    function succeeded(Witnet.Result memory _result)
      internal pure
      returns (bool)
    {
        return _result.success;
    }

    /// ===============================================================================================================
    /// --- WitnetLib private methods ---------------------------------------------------------------------------------

    /// @notice Decode an errored `Witnet.Result` as a `uint[]`.
    /// @param _result An instance of `Witnet.Result`.
    /// @return The `uint[]` error parameters as decoded from the `Witnet.Result`.
    function _errorsFromResult(Witnet.Result memory _result)
        private pure
        returns(uint[] memory)
    {
        require(
            failed(_result),
            "WitnetLib: no actual error"
        );
        return _result.value.readUintArray();
    }

    /// @notice Decode a CBOR value into a Witnet.Result instance.
    /// @param _cborValue An instance of `Witnet.Value`.
    /// @return A `Witnet.Result` instance.
    function _resultFromCborValue(WitnetCBOR.CBOR memory _cborValue)
        private pure
        returns (Witnet.Result memory)    
    {
        // Witnet uses CBOR tag 39 to represent RADON error code identifiers.
        // [CBOR tag 39] Identifiers for CBOR: https://github.com/lucas-clemente/cbor-specs/blob/master/id.md
        bool success = _cborValue.tag != 39;
        return Witnet.Result(success, _cborValue);
    }

    /// @notice Convert a stage index number into the name of the matching Witnet request stage.
    /// @param _stageIndex A `uint64` identifying the index of one of the Witnet request stages.
    /// @return The name of the matching stage.
    function _stageName(uint64 _stageIndex)
        private pure
        returns (string memory)
    {
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


    /// ===============================================================================================================
    /// --- WitnetLib public methods (if used library will have to linked to calling contracts) -----------------------

    /// ----------------------------- public decoding methods ---------------------------------------------------------

    function asAddress(Witnet.Result memory _result)
        public pure
        returns (address)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `address` from errored result."
        );
        if (_result.value.majorType == uint8(WitnetCBOR.MAJOR_TYPE_BYTES)) {
            return _result.value.readBytes().toAddress();
        } else {
            revert("WitnetLib: reading address from string not yet supported.");
        }
    }

    /// @notice Decode a boolean value from a Witnet.Result as an `bool` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `bool` decoded from the Witnet.Result.
    function asBool(Witnet.Result memory _result)
        public pure
        returns (bool)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `bool` value from errored result."
        );
        return _result.value.readBool();
    }

    /// @notice Decode a bytes value from a Witnet.Result as a `bytes` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `bytes` decoded from the Witnet.Result.
    function asBytes(Witnet.Result memory _result)
        public pure
        returns(bytes memory)
    {
        require(
            _result.success,
            "WitnetLib: Tried to read bytes value from errored Witnet.Result"
        );
        return _result.value.readBytes();
    }

    function asBytes4(Witnet.Result memory _result)
        public pure
        returns (bytes4)
    {
        return asBytes(_result).toBytes4();
    }

    /// @notice Decode a bytes value from a Witnet.Result as a `bytes32` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `bytes32` decoded from the Witnet.Result.
    function asBytes32(Witnet.Result memory _result)
        public pure
        returns (bytes32)
    {
        return asBytes(_result).toBytes32();
    }

    /// @notice Decode an error code from a Witnet.Result as a member of `Witnet.ErrorCodes`.
    /// @param _result An instance of `Witnet.Result`.
    function asErrorCode(Witnet.Result memory _result)
        public pure
        returns (Witnet.ErrorCodes)
    {
        uint[] memory _errors = _errorsFromResult(_result);
        if (_errors.length == 0) {
            return Witnet.ErrorCodes.Unknown;
        } else {
            return Witnet.ErrorCodes(_errors[0]);
        }
    }

    /// @notice Generate a suitable error message for a member of `Witnet.ErrorCodes` and its corresponding arguments.
    /// @dev WARN: Note that client contracts should wrap this function into a try-catch foreseing potential errors generated in this function
    /// @param _result An instance of `Witnet.Result`.
    /// @return _errorCode Decoded error code.
    /// @return _errorString Decoded error message.
    function asErrorMessage(Witnet.Result memory _result)
        public pure
        returns (
            Witnet.ErrorCodes _errorCode,
            string memory _errorString
        )
    {
        uint[] memory _errors = _errorsFromResult(_result);
        if (_errors.length == 0) {
            return (
                Witnet.ErrorCodes.Unknown,
                "Unknown error: no error code."
            );
        }
        else {
            _errorCode = Witnet.ErrorCodes(_errors[0]);
        }
        if (
            _errorCode == Witnet.ErrorCodes.SourceScriptNotCBOR
                && _errors.length >= 2
        ) {
            _errorString = string(abi.encodePacked(
                "Source script #",
                toString(uint8(_errors[1])),
                " was not a valid CBOR value"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.SourceScriptNotArray
                && _errors.length >= 2
        ) {
            _errorString = string(abi.encodePacked(
                "The CBOR value in script #",
                toString(uint8(_errors[1])),
                " was not an Array of calls"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.SourceScriptNotRADON
                && _errors.length >= 2
        ) {
            _errorString = string(abi.encodePacked(
                "The CBOR value in script #",
                toString(uint8(_errors[1])),
                " was not a valid Data Request"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.RequestTooManySources
                && _errors.length >= 2
        ) {
            _errorString = string(abi.encodePacked(
                "The request contained too many sources (", 
                toString(uint8(_errors[1])), 
                ")"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.ScriptTooManyCalls
                && _errors.length >= 4
        ) {
            _errorString = string(abi.encodePacked(
                "Script #",
                toString(uint8(_errors[2])),
                " from the ",
                _stageName(uint8(_errors[1])),
                " stage contained too many calls (",
                toString(uint8(_errors[3])),
                ")"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.UnsupportedOperator
                && _errors.length >= 5
        ) {
            _errorString = string(abi.encodePacked(
                "Operator code 0x",
                toHexString(uint8(_errors[4])),
                " found at call #",
                toString(uint8(_errors[3])),
                " in script #",
                toString(uint8(_errors[2])),
                " from ",
                _stageName(uint8(_errors[1])),
                " stage is not supported"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.HTTP
                && _errors.length >= 3
        ) {
            _errorString = string(abi.encodePacked(
                "Source #",
                toString(uint8(_errors[1])),
                " could not be retrieved. Failed with HTTP error code: ",
                toString(uint8(_errors[2] / 100)),
                toString(uint8(_errors[2] % 100 / 10)),
                toString(uint8(_errors[2] % 10))
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.RetrievalTimeout
                && _errors.length >= 2
        ) {
            _errorString = string(abi.encodePacked(
                "Source #",
                toString(uint8(_errors[1])),
                " could not be retrieved because of a timeout"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.Underflow
                && _errors.length >= 5
        ) {
            _errorString = string(abi.encodePacked(
                "Underflow at operator code 0x",
                toHexString(uint8(_errors[4])),
                " found at call #",
                toString(uint8(_errors[3])),
                " in script #",
                toString(uint8(_errors[2])),
                " from ",
                _stageName(uint8(_errors[1])),
                " stage"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.Overflow
                && _errors.length >= 5
        ) {
            _errorString = string(abi.encodePacked(
                "Overflow at operator code 0x",
                toHexString(uint8(_errors[4])),
                " found at call #",
                toString(uint8(_errors[3])),
                " in script #",
                toString(uint8(_errors[2])),
                " from ",
                _stageName(uint8(_errors[1])),
                " stage"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.DivisionByZero
                && _errors.length >= 5
        ) {
            _errorString = string(abi.encodePacked(
                "Division by zero at operator code 0x",
                toHexString(uint8(_errors[4])),
                " found at call #",
                toString(uint8(_errors[3])),
                " in script #",
                toString(uint8(_errors[2])),
                " from ",
                _stageName(uint8(_errors[1])),
                " stage"
            ));
        } else if (
            _errorCode == Witnet.ErrorCodes.BridgeMalformedRequest
        ) {
            _errorString = "The structure of the request is invalid and it cannot be parsed";
        } else if (
            _errorCode == Witnet.ErrorCodes.BridgePoorIncentives
        ) {
            _errorString = "The request has been rejected by the bridge node due to poor incentives";
        } else if (
            _errorCode == Witnet.ErrorCodes.BridgeOversizedResult
        ) {
            _errorString = "The request result length exceeds a bridge contract defined limit";
        } else {
            _errorString = string(abi.encodePacked(
                "Unknown error (0x",
                toHexString(uint8(_errors[0])),
                ")"
            ));
        }
        return (
            _errorCode,
            _errorString
        );
    }

    /// @notice Decode a fixed16 (half-precision) numeric value from a Witnet.Result as an `int32` value.
    /// @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values.
    /// by 5 decimal orders so as to get a fixed precision of 5 decimal positions, which should be OK for most `fixed16`.
    /// use cases. In other words, the output of this method is 10,000 times the actual value, encoded into an `int32`.
    /// @param _result An instance of Witnet.Result.
    /// @return The `int128` decoded from the Witnet.Result.
    function asFixed16(Witnet.Result memory _result)
        public pure
        returns (int32)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `fixed16` value from errored result."
        );
        return _result.value.readFloat16();
    }

    /// @notice Decode an array of fixed16 values from a Witnet.Result as an `int32[]` array.
    /// @param _result An instance of Witnet.Result.
    /// @return The `int128[]` decoded from the Witnet.Result.
    function asFixed16Array(Witnet.Result memory _result)
        public pure
        returns (int32[] memory)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `fixed16[]` value from errored result."
        );
        return _result.value.readFloat16Array();
    }

    /// @notice Decode a integer numeric value from a Witnet.Result as an `int128` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `int` decoded from the Witnet.Result.
    function asInt(Witnet.Result memory _result)
      public pure
      returns (int)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `int` value from errored result."
        );
        return _result.value.readInt();
    }

    /// @notice Decode an array of integer numeric values from a Witnet.Result as an `int[]` array.
    /// @param _result An instance of Witnet.Result.
    /// @return The `int[]` decoded from the Witnet.Result.
    function asIntArray(Witnet.Result memory _result)
        public pure
        returns (int[] memory)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `int[]` value from errored result."
        );
        return _result.value.readIntArray();
    }

    /// @notice Decode a string value from a Witnet.Result as a `string` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `string` decoded from the Witnet.Result.
    function asString(Witnet.Result memory _result)
        public pure
        returns(string memory)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `string` value from errored result."
        );
        return _result.value.readString();
    }

    /// @notice Decode an array of string values from a Witnet.Result as a `string[]` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `string[]` decoded from the Witnet.Result.
    function asStringArray(Witnet.Result memory _result)
        public pure
        returns (string[] memory)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `string[]` value from errored result.");
        return _result.value.readStringArray();
    }

    /// @notice Decode a natural numeric value from a Witnet.Result as a `uint` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `uint` decoded from the Witnet.Result.
    function asUint(Witnet.Result memory _result)
        public pure
        returns(uint)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `uint64` value from errored result"
        );
        return _result.value.readUint();
    }

    /// @notice Decode an array of natural numeric values from a Witnet.Result as a `uint[]` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `uint[]` decoded from the Witnet.Result.
    function asUintArray(Witnet.Result memory _result)
        public pure
        returns (uint[] memory)
    {
        require(
            _result.success,
            "WitnetLib: tried to read `uint[]` value from errored result."
        );
        return _result.value.readUintArray();
    }

    /// @notice Decode raw CBOR bytes into a Witnet.Result instance.
    /// @param _cborBytes Raw bytes representing a CBOR-encoded value.
    /// @return A `Witnet.Result` instance.
    function resultFromCborBytes(bytes memory _cborBytes)
        public pure
        returns (Witnet.Result memory)
    {
        WitnetCBOR.CBOR memory cborValue = WitnetCBOR.valueFromBytes(_cborBytes);
        return _resultFromCborValue(cborValue);
    }

    /// ----------------------------- public encoding methods ---------------------------------------------------------

    /// @notice Encode bytes array into given major type (UTF-8 not yet supported)
    /// @param buf Bytes array
    /// @return Marshaled bytes
    function encode(bytes memory buf, uint majorType)
        public pure
        returns (bytes memory)
    {
        uint len = buf.length;
        if (len < 23) {
            return abi.encodePacked(
                uint8((majorType << 5) | uint8(len)),
                buf
            );
        } else {
            uint8 buf0 = uint8((majorType << 5));
            bytes memory buf1;
            if (len <= 0xff) {
                buf0 |= 24;
                buf1 = abi.encodePacked(uint8(len));                
            } else if (len <= 0xffff) {
                buf0 |= 25;
                buf1 = abi.encodePacked(uint16(len));
            } else if (len <= 0xffffffff) {
                buf0 |= 26;
                buf1 = abi.encodePacked(uint32(len));
            } else {
                buf0 |= 27;
                buf1 = abi.encodePacked(uint64(len));
            }
            return abi.encodePacked(
                buf0,
                buf1,
                buf
            );
        }
    }

    /// @notice Encode bytes array.
    /// @param buf Bytes array
    /// @return Mashaled bytes
    function encode(bytes memory buf)
        public pure
        returns (bytes memory)
    {
        return encode(buf, WitnetCBOR.MAJOR_TYPE_BYTES);
    } 

    /// @notice Encode string array (UTF-8 not yet supported).
    /// @param str String bytes.
    /// @return Mashaled bytes
    function encode(string memory str)
        public pure
        returns (bytes memory)
    {
        return encode(bytes(str), WitnetCBOR.MAJOR_TYPE_STRING);
    }

    /// @dev Encode uint64 into tagged varint.
    /// @dev See https://developers.google.com/protocol-buffers/docs/encoding#varints.
    /// @param n Number
    /// @param t Tag
    /// @return buf Marshaled bytes
    function encode(uint64 n, bytes1 t)
        public pure
        returns (bytes memory buf)
    {
        unchecked {
            // Count the number of groups of 7 bits
            // We need this pre-processing step since Solidity doesn't allow dynamic memory resizing
            uint64 tmp = n;
            uint64 numBytes = 2;
            while (tmp > 0x7F) {
                tmp = tmp >> 7;
                numBytes += 1;
            }
            buf = new bytes(numBytes);
            tmp = n;
            buf[0] = t;
            for (uint64 i = 1; i < numBytes; i++) {
                // Set the first bit in the byte for each group of 7 bits
                buf[i] = bytes1(0x80 | uint8(tmp & 0x7F));
                tmp = tmp >> 7;
            }
            // Unset the first bit of the last byte
            buf[numBytes - 1] &= 0x7F;
        }
    }

    function encode(WitnetV2.DataSource memory _dds)
        public pure
        returns (bytes memory)
    {
        assert(_dds.headers[0].length == _dds.headers[1].length);
        bytes memory _encodedMethod = encode(uint64(_dds.method), bytes1(0x08));
        bytes memory _encodedUrl;
        if (bytes(_dds.url).length > 0) {
            _encodedUrl = abi.encodePacked(
                encode(uint64(bytes(_dds.url).length), bytes1(0x12)),
                bytes(_dds.url)
            );
        }
        bytes memory _encodedScript;
        if (_dds.script.length > 0) {
            _encodedScript = abi.encodePacked(
                encode(uint64(_dds.script.length), bytes1(0x1a)),
                _dds.script
            );
        }
        bytes memory _encodedBody;
        if (bytes(_dds.body).length > 0) {
            _encodedBody = abi.encodePacked(
                encode(uint64(bytes(_dds.body).length), bytes1(0x22))
            );
        }
        bytes memory _encodedHeaders;
        if (_dds.headers[0].length > 0) {
            bytes memory _partials;
            for (uint _ix = 0; _ix < _dds.headers[0].length; ) {
                _partials = abi.encodePacked(
                    _partials,
                    encode(uint64(bytes(_dds.headers[0][_ix]).length), bytes1(0x0a)),
                    bytes(_dds.headers[0][_ix]),
                    encode(uint64(bytes(_dds.headers[1][_ix]).length), bytes1(0x12)),
                    bytes(_dds.headers[1][_ix])
                );
            }
            _encodedHeaders = abi.encodePacked(
                encode(uint64(_partials.length), bytes1(0x2a)),
                _partials
            );
        }
        uint _innerSize = (
            _encodedMethod.length
                + _encodedUrl.length
                + _encodedScript.length
                + _encodedBody.length
                + _encodedHeaders.length
        );
        return abi.encodePacked(
            encode(uint64(_innerSize), bytes1(0x12)),
            _encodedMethod,
            _encodedUrl,
            _encodedScript,
            _encodedBody,
            _encodedHeaders
        );
    }

    function encode(WitnetV2.RadonSLA memory _sla)
        public pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encode(uint64(_sla.witnessReward), bytes1(0x10)),
            encode(uint64(_sla.numWitnesses), bytes1(0x18)),
            encode(uint64(_sla.commitRevealFee), bytes1(0x20)),
            encode(uint64(_sla.minConsensusPercentage), bytes1(0x28)),
            encode(uint64(_sla.collateral), bytes1(0x30))
        );
    }

    function replaceCborStringsFromBytes(
            bytes memory data,
            string[] memory args
        )
        public pure
        returns (WitnetCBOR.CBOR memory cbor)
    {
        cbor = WitnetCBOR.valueFromBytes(data);
        while (!cbor.eof()) {
            if (cbor.majorType == WitnetCBOR.MAJOR_TYPE_STRING) {
                _replaceWildcards(cbor, args);
            } else {
                cbor.skip();
            }
        }
    }

    function _replaceWildcards(WitnetCBOR.CBOR memory self, string[] memory args)
        private pure
    {
        uint _rewind = self.len;
        uint _start = self.buffer.cursor;
        bytes memory _current_text = bytes(self.readString());
        uint _current_cbor_length = _current_text.length + _rewind;
        bytes memory _new_text = WitnetBuffer.replace(bytes(_current_text), args);
        if (keccak256(_new_text) != keccak256(bytes(_current_text))) {
            bytes memory _new_cbor_pokes = encode(string(_new_text));
            self.buffer.cursor = _start - _rewind;
            self.buffer.mutate(_current_cbor_length, _new_cbor_pokes);
        }
        self.buffer.cursor = _start;
        self.skip();
    }

}