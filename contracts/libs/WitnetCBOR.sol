// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetBuffer.sol";

/// @title A minimalistic implementation of “RFC 7049 Concise Binary Object Representation”
/// @notice This library leverages a buffer-like structure for step-by-step decoding of bytes so as to minimize
/// the gas cost of decoding them into a useful native type.
/// @dev Most of the logic has been borrowed from Patrick Gansterer’s cbor.js library: https://github.com/paroga/cbor-js
/// @author The Witnet Foundation.
/// 
/// TODO: add support for Map (majorType = 5)
/// TODO: add support for Float32 (majorType = 7, additionalInformation = 26)
/// TODO: add support for Float64 (majorType = 7, additionalInformation = 27) 

library WitnetCBOR {

  using WitnetBuffer for WitnetBuffer.Buffer;
  using WitnetCBOR for WitnetCBOR.CBOR;

  /// Data struct following the RFC-7049 standard: Concise Binary Object Representation.
  struct CBOR {
      WitnetBuffer.Buffer buffer;
      uint8 initialByte;
      uint8 majorType;
      uint8 additionalInformation;
      uint64 len;
      uint64 tag;
  }

  uint8 internal constant MAJOR_TYPE_INT = 0;
  uint8 internal constant MAJOR_TYPE_NEGATIVE_INT = 1;
  uint8 internal constant MAJOR_TYPE_BYTES = 2;
  uint8 internal constant MAJOR_TYPE_STRING = 3;
  uint8 internal constant MAJOR_TYPE_ARRAY = 4;
  uint8 internal constant MAJOR_TYPE_MAP = 5;
  uint8 internal constant MAJOR_TYPE_TAG = 6;
  uint8 internal constant MAJOR_TYPE_CONTENT_FREE = 7;

  uint32 internal constant UINT32_MAX = type(uint32).max;
  uint64 internal constant UINT64_MAX = type(uint64).max;
  
  error EmptyArray();
  error InvalidLengthEncoding(uint length);
  error UnexpectedMajorType(uint read, uint expected);
  error UnsupportedPrimitive(uint primitive);
  error UnsupportedMajorType(uint unexpected);  

  modifier isMajorType(
      WitnetCBOR.CBOR memory _cbor,
      uint8 _expected
  ) {
    if (_cbor.majorType != _expected) {
      revert UnexpectedMajorType(_cbor.majorType, _expected);
    }
    _;
  }

  modifier notEmpty(WitnetBuffer.Buffer memory _buf) {
    if (_buf.data.length == 0) {
      revert WitnetBuffer.EmptyBuffer();
    }
    _;
  }

  function eof(CBOR memory cbor)
    internal pure
    returns (bool)
  {
    return cbor.buffer.cursor >= cbor.buffer.data.length;
  }

  /// @notice Decode a CBOR structure from raw bytes.
  /// @dev This is the main factory for CBOR instances, which can be later decoded into native EVM types.
  /// @param _cborBytes Raw bytes representing a CBOR-encoded value.
  /// @return A `CBOR` instance containing a partially decoded value.
  function valueFromBytes(bytes memory _cborBytes)
    internal pure
    returns (CBOR memory)
  {
    WitnetBuffer.Buffer memory buffer = WitnetBuffer.Buffer(_cborBytes, 0);
    return valueFromBuffer(buffer);
  }

  /// @notice Decode a CBOR structure from raw bytes.
  /// @dev This is an alternate factory for CBOR instances, which can be later decoded into native EVM types.
  /// @param _buffer A Buffer structure representing a CBOR-encoded value.
  /// @return A `CBOR` instance containing a partially decoded value.
  function valueFromBuffer(WitnetBuffer.Buffer memory _buffer)
    internal pure
    notEmpty(_buffer)
    returns (CBOR memory)
  {
    uint8 _initialByte;
    uint8 _majorType = 255;
    uint8 _additionalInformation;
    uint64 _tag = UINT64_MAX;
    uint256 _len;

    bool _isTagged = true;
    while (_isTagged) {
      // Extract basic CBOR properties from input bytes
      _initialByte = _buffer.readUint8();
      _len ++;
      _majorType = _initialByte >> 5;
      _additionalInformation = _initialByte & 0x1f;
      // Early CBOR tag parsing.
      if (_majorType == MAJOR_TYPE_TAG) {
        uint _cursor = _buffer.cursor;
        _tag = readLength(_buffer, _additionalInformation);
        _len += _buffer.cursor - _cursor;
      } else {
        _isTagged = false;
      }
    }
    if (_majorType > MAJOR_TYPE_CONTENT_FREE) {
      revert UnsupportedMajorType(_majorType);
    }
    return CBOR(
      _buffer,
      _initialByte,
      _majorType,
      _additionalInformation,
      uint64(_len),
      _tag
    );
  }

  /// @notice Decode a CBOR structure from raw bytes.
  /// @dev This is an alternate factory for CBOR instances, which can be later decoded into native EVM types.
  /// @param _buffer A Buffer structure representing a CBOR-encoded value.
  /// @return _value A `CBOR` instance containing a partially decoded value.
  function _valueFromForkedBuffer(WitnetBuffer.Buffer memory _buffer)
    private pure
    notEmpty(_buffer)
    returns (CBOR memory _value)
  {
    uint8 _initialByte;
    uint8 _majorType = 255;
    uint8 _additionalInformation;
    uint64 _tag = UINT64_MAX;
    uint256 _len = 0;

    WitnetBuffer.Buffer memory _newBuffer = _buffer.fork();
    bool _isTagged = true;
    while (_isTagged) {
      // Extract basic CBOR properties from input bytes
      _initialByte = _newBuffer.readUint8();
      _len ++;
      _majorType = _initialByte >> 5;
      _additionalInformation = _initialByte & 0x1f;
      // Early CBOR tag parsing.
      if (_majorType == MAJOR_TYPE_TAG) {
        uint _cursor = _newBuffer.cursor;
        _tag = readLength(_newBuffer, _additionalInformation);
        _len += _newBuffer.cursor - _cursor;

      } else {
        _isTagged = false;
      }
    }
    if (_majorType > MAJOR_TYPE_CONTENT_FREE) {
      revert UnsupportedMajorType(_majorType);
    }
    _value.buffer = _newBuffer;
    _value.initialByte = _initialByte;
    _value.majorType = _majorType;
    _value.additionalInformation = _additionalInformation;
    _value.len = uint64(_len);
    _value.tag = _tag;
  }

  /// Read the length of a CBOR indifinite-length item (arrays, maps, byte strings and text) from a buffer, consuming
  /// as many bytes as specified by the first byte.
  function _readIndefiniteStringLength(
      WitnetBuffer.Buffer memory _buffer,
      uint8 _majorType
    )
    private pure
    returns (uint64 _length)
  {
    uint8 _initialByte = _buffer.readUint8();
    if (_initialByte == 0xff) {
      return UINT64_MAX;
    }
    _length = readLength(
      _buffer,
      _initialByte & 0x1f
    );
    if (_length >= UINT64_MAX) {
      revert InvalidLengthEncoding(_length);
    } else if (_majorType != (_initialByte >> 5)) {
      revert UnexpectedMajorType((_initialByte >> 5), _majorType);
    }
  }

  function _seekNext(WitnetCBOR.CBOR memory _cbor)
    private pure
    returns (WitnetCBOR.CBOR memory)
  {
    if (_cbor.majorType == MAJOR_TYPE_INT || _cbor.majorType == MAJOR_TYPE_NEGATIVE_INT) {
      readInt(_cbor);
    } else if (_cbor.majorType == MAJOR_TYPE_BYTES) {
      readBytes(_cbor);
    } else if (_cbor.majorType == MAJOR_TYPE_STRING) {
      readString(_cbor);
    } else if (_cbor.majorType == MAJOR_TYPE_ARRAY) {
      CBOR[] memory _items = readArray(_cbor);
      _cbor = _items[_items.length - 1];
    } else {
      revert UnsupportedMajorType(_cbor.majorType);
    }
    return _cbor;
  }

  function _skipArray(CBOR memory _cbor)
    private pure
    isMajorType(_cbor, MAJOR_TYPE_ARRAY)
    returns (CBOR memory _next)
  {
    _next = _valueFromForkedBuffer(_cbor.buffer);
    CBOR[] memory _items = readArray(_cbor);
    if (_items.length == 0) {
      revert EmptyArray();
    }
  }

  function _skipBytes(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_BYTES)
    returns (CBOR memory)
  {
    _cbor.len = readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_cbor.len < UINT32_MAX) {
      _cbor.buffer.seek(_cbor.len);
      return _valueFromForkedBuffer(_cbor.buffer);
    } 
    // TODO: support skipping indefitine length bytes array
    revert InvalidLengthEncoding(_cbor.len);
  }

  function _skipInt(CBOR memory _cbor)
    private pure
    returns (CBOR memory _next)
  {
    if (_cbor.majorType == MAJOR_TYPE_INT || _cbor.majorType == MAJOR_TYPE_NEGATIVE_INT) {
      _next = _valueFromForkedBuffer(_cbor.buffer);
    } else {
      revert UnexpectedMajorType(_cbor.majorType, 1);
    }
  }

  function _skipPrimitive(CBOR memory _cbor)
    private pure
    isMajorType(_cbor, MAJOR_TYPE_CONTENT_FREE)
    returns (WitnetCBOR.CBOR memory)
  {
    if (_cbor.additionalInformation == 25) {
      _cbor.buffer.seek(2);
      
    } else if (
      _cbor.additionalInformation != 20
        && _cbor.additionalInformation != 21
    ) {
      revert UnsupportedPrimitive(_cbor.additionalInformation);
    }
    return _valueFromForkedBuffer(_cbor.buffer);
  }

  function _skipText(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_STRING)
    returns (CBOR memory)
  {
    _cbor.len = readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_cbor.len < UINT64_MAX) {
      _cbor.buffer.seek(_cbor.len);
      return valueFromBuffer(_cbor.buffer);
    }
    // TODO: support skipping indefitine length text array
    revert InvalidLengthEncoding(_cbor.len);  
  }

  function next(CBOR memory self)
      internal pure
  {
    uint8 _initialByte;
    uint8 _majorType = 255;
    uint8 _additionalInformation;
    uint64 _tag = UINT64_MAX;
    uint256 _len = 0;
    bool _isTagged = true;
    while (_isTagged) {
      // Extract basic CBOR properties from input bytes
      _initialByte = self.buffer.readUint8();
      _len ++;
      _majorType = _initialByte >> 5;
      _additionalInformation = _initialByte & 0x1f;
      // Early CBOR tag parsing.
      if (_majorType == MAJOR_TYPE_TAG) {
        uint _cursor = self.buffer.cursor;
        _tag = readLength(self.buffer, _additionalInformation);
        _len += self.buffer.cursor - _cursor;

      } else {
        _isTagged = false;
      }
    }
    if (_majorType > MAJOR_TYPE_CONTENT_FREE) {
      revert UnsupportedMajorType(_majorType);
    }
    self.initialByte = _initialByte;
    self.majorType = _majorType;
    self.additionalInformation = _additionalInformation;
    self.len = uint64(_len);
    self.tag = _tag;
  }

  function skip(CBOR memory self)
      internal pure
  {
    if (
      self.majorType == MAJOR_TYPE_INT
        || self.majorType == MAJOR_TYPE_NEGATIVE_INT
    ) {
      self.buffer.cursor += self.length();
    } else if (
        self.majorType == MAJOR_TYPE_STRING
          || self.majorType == MAJOR_TYPE_BYTES
    ) {
      self.buffer.cursor += readLength(self.buffer, self.additionalInformation);
    } else if (
      self.majorType == MAJOR_TYPE_ARRAY
    ) { 
      readLength(self.buffer, self.additionalInformation);      
    } else if (
      self.majorType != MAJOR_TYPE_CONTENT_FREE
    ) {
      revert UnsupportedMajorType(self.majorType);
    }
    if (!self.eof()) {
      self.next();
    }
  }

  function length(CBOR memory self)
    internal pure
    returns (uint64)
  {
    if (self.additionalInformation < 24) {
      return self.additionalInformation;
    } else if (self.additionalInformation > 27) {
      revert InvalidLengthEncoding(self.additionalInformation);
    } else {
      return uint64(1 << (self.additionalInformation - 24));
    }
  }

  function readArray(CBOR memory self)
    internal pure
    isMajorType(self, MAJOR_TYPE_ARRAY)
    returns (CBOR[] memory items)
  {
    uint64 len = readLength(self.buffer, self.additionalInformation);
    items = new CBOR[](len + 1);
    for (uint _ix = 0; _ix < len; _ix ++) {
      items[_ix] = _valueFromForkedBuffer(self.buffer);
      self.buffer.cursor = items[_ix].buffer.cursor;
      self.majorType = items[_ix].majorType;
      self.additionalInformation = items[_ix].additionalInformation;
      self = _seekNext(self);
    }
    items[len] = self;
  }

  /// Reads the length of the next CBOR item from a buffer, consuming a different number of bytes depending on the
  /// value of the `additionalInformation` argument.
  function readLength(
      WitnetBuffer.Buffer memory _buffer,
      uint8 _additionalInformation
    ) 
    internal pure
    returns (uint64)
  {
    if (_additionalInformation < 24) {
      return _additionalInformation;
    }
    if (_additionalInformation == 24) {
      return _buffer.readUint8();
    }
    if (_additionalInformation == 25) {
      return _buffer.readUint16();
    }
    if (_additionalInformation == 26) {
      return _buffer.readUint32();
    }
    if (_additionalInformation == 27) {
      return _buffer.readUint64();
    }
    if (_additionalInformation == 31) {
      return UINT64_MAX;
    }
    revert InvalidLengthEncoding(_additionalInformation);
  }

  /// @notice Read a `CBOR` structure into a native `bool` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return The value represented by the input, as a `bool` value.
  function readBool(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_CONTENT_FREE)
    returns (bool)
  {
    if (_cbor.additionalInformation == 20) {
      return false;
    } else if (_cbor.additionalInformation == 21) {
      return true;
    } else {
      revert UnsupportedPrimitive(_cbor.additionalInformation);
    }
  }

  /// @notice Decode a `CBOR` structure into a native `bytes` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return _output The value represented by the input, as a `bytes` value.   
  function readBytes(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_BYTES)
    returns (bytes memory _output)
  {
    _cbor.len = readLength(
      _cbor.buffer,
      _cbor.additionalInformation
    );
    if (_cbor.len == UINT32_MAX) {
      // These checks look repetitive but the equivalent loop would be more expensive.
      uint32 _length = uint32(_readIndefiniteStringLength(
        _cbor.buffer,
        _cbor.majorType
      ));
      if (_length < UINT32_MAX) {
        _output = abi.encodePacked(_cbor.buffer.read(_length));
        _length = uint32(_readIndefiniteStringLength(
          _cbor.buffer,
          _cbor.majorType
        ));
        if (_length < UINT32_MAX) {
          _output = abi.encodePacked(
            _output,
            _cbor.buffer.read(_length)
          );
        }
      }
    } else {
      return _cbor.buffer.read(uint32(_cbor.len));
    }
  }

  /// @notice Decode a `CBOR` structure into a `fixed16` value.
  /// @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values
  /// by 5 decimal orders so as to get a fixed precision of 5 decimal positions, which should be OK for most `fixed16`
  /// use cases. In other words, the output of this method is 10,000 times the actual value, encoded into an `int32`.
  /// @param _cbor An instance of `CBOR`.
  /// @return The value represented by the input, as an `int128` value.
  function readFloat16(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_CONTENT_FREE)
    returns (int32)
  {
    if (_cbor.additionalInformation == 25) {
      return _cbor.buffer.readFloat16();
    } else {
      revert UnsupportedPrimitive(_cbor.additionalInformation);
    }
  }

  /// @notice Decode a `CBOR` structure into a native `int128[]` value whose inner values follow the same convention 
  /// @notice as explained in `decodeFixed16`.
  /// @param _cbor An instance of `CBOR`.
  function readFloat16Array(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_ARRAY)
    returns (int32[] memory _values)
  {
    uint64 _length = readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < UINT64_MAX) {
      _values = new int32[](_length);
      for (uint64 _i = 0; _i < _length; ) {
        CBOR memory _item = valueFromBuffer(_cbor.buffer);
        _values[_i] = readFloat16(_item);
        unchecked {
          _i ++;
        }
      }
    } else {
      revert InvalidLengthEncoding(_length);
    }
  }

  /// @notice Decode a `CBOR` structure into a native `int128` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return The value represented by the input, as an `int128` value.
  function readInt(CBOR memory _cbor)
    internal pure
    returns (int)
  {
    if (_cbor.majorType == 1) {
      uint64 _value = readLength(
        _cbor.buffer,
        _cbor.additionalInformation
      );
      return int(-1) - int(uint(_value));
    } else if (_cbor.majorType == 0) {
      // Any `uint64` can be safely casted to `int128`, so this method supports majorType 1 as well so as to have offer
      // a uniform API for positive and negative numbers
      return int(readUint(_cbor));
    }
    else {
      revert UnexpectedMajorType(_cbor.majorType, 1);
    }
  }

  /// @notice Decode a `CBOR` structure into a native `int[]` value.
  /// @param _cbor instance of `CBOR`.
  /// @return _array The value represented by the input, as an `int[]` value.
  function readIntArray(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_ARRAY)
    returns (int[] memory _array)
  {
    uint64 _length = readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < UINT64_MAX) {
      _array = new int[](_length);
      for (uint _i = 0; _i < _length; ) {
        CBOR memory _item = valueFromBuffer(_cbor.buffer);
        _array[_i] = readInt(_item);
        unchecked {
          _i ++;
        }
      }
    } else {
      revert InvalidLengthEncoding(_length);
    }
  }

  /// @notice Decode a `CBOR` structure into a native `string` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return _text The value represented by the input, as a `string` value.
  function readString(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_STRING)
    returns (string memory _text)
  {
    _cbor.len = readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_cbor.len == UINT64_MAX) {
      bool _done;
      while (!_done) {
        uint64 _length = _readIndefiniteStringLength(
          _cbor.buffer,
          _cbor.majorType
        );
        if (_length < UINT64_MAX) {
          _text = string(abi.encodePacked(
            _text,
            _cbor.buffer.readText(_length / 4)
          ));
        } else {
          _done = true;
        }
      }
    } else {
      return string(_cbor.buffer.readText(_cbor.len));
    }
  }

  /// @notice Decode a `CBOR` structure into a native `string[]` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return _strings The value represented by the input, as an `string[]` value.
  function readStringArray(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_ARRAY)
    returns (string[] memory _strings)
  {
    uint _length = readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < UINT64_MAX) {
      _strings = new string[](_length);
      for (uint _i = 0; _i < _length; ) {
        CBOR memory _item = valueFromBuffer(_cbor.buffer);
        _strings[_i] = readString(_item);
        unchecked {
          _i ++;
        }
      }
    } else {
      revert InvalidLengthEncoding(_length);
    }
  }

  /// @notice Decode a `CBOR` structure into a native `uint64` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return The value represented by the input, as an `uint64` value.
  function readUint(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_INT)
    returns (uint)
  {
    return readLength(
      _cbor.buffer,
      _cbor.additionalInformation
    );
  }

  /// @notice Decode a `CBOR` structure into a native `uint64[]` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return _values The value represented by the input, as an `uint64[]` value.
  function readUintArray(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MAJOR_TYPE_ARRAY)
    returns (uint[] memory _values)
  {
    uint64 _length = readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < UINT64_MAX) {
      _values = new uint[](_length);
      for (uint _ix = 0; _ix < _length; ) {
        CBOR memory _item = valueFromBuffer(_cbor.buffer);
        _values[_ix] = readUint(_item);
        unchecked {
          _ix ++;
        }
      }
    } else {
      revert InvalidLengthEncoding(_length);
    }
  }  
 
}