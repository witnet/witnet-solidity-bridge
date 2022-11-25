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

  enum MajorTypes {
    /* 0 */ Uint,
    /* 1 */ Int,
    /* 2 */ Bytes,
    /* 3 */ String,
    /* 4 */ Array,
    /* 5 */ Map,
    /* 6 */ Tag,
    /* 7 */ Primitive
  }
  
  error EmptyArray();
  error InvalidLengthEncoding(uint length);
  error UnexpectedMajorType(uint read, uint expected);
  error UnsupportedPrimitive(uint primitive);
  error UnsupportedMajorType(uint unexpected);  

  modifier isMajorType(
      WitnetCBOR.CBOR memory _cbor,
      MajorTypes _expected
  ) {
    if (_cbor.majorType != uint(_expected)) {
      revert UnexpectedMajorType(_cbor.majorType, uint(_expected));
    }
    _;
  }

  modifier notEmpty(WitnetBuffer.Buffer memory _buf) {
    if (_buf.data.length == 0) {
      revert WitnetBuffer.EmptyBuffer();
    }
    _;
  }

  /// Data struct following the RFC-7049 standard: Concise Binary Object Representation.
  struct CBOR {
      WitnetBuffer.Buffer buffer;
      uint8 initialByte;
      uint8 majorType;
      uint8 additionalInformation;
      uint64 len;
      uint64 tag;
  }

  uint32 constant internal _UINT32_MAX = type(uint32).max;
  uint64 constant internal _UINT64_MAX = type(uint64).max;

  /// @notice Decode a CBOR structure from raw bytes.
  /// @dev This is the main factory for CBOR instances, which can be later decoded into native EVM types.
  /// @param _cborBytes Raw bytes representing a CBOR-encoded value.
  /// @return A `CBOR` instance containing a partially decoded value.
  function valueFromBytes(bytes memory _cborBytes)
    internal pure
    returns (CBOR memory)
  {
    WitnetBuffer.Buffer memory buffer = WitnetBuffer.Buffer(_cborBytes, 0);
    return _valueFromBuffer(buffer);
  }

  /// @notice Decode a CBOR structure from raw bytes.
  /// @dev This is an alternate factory for CBOR instances, which can be later decoded into native EVM types.
  /// @param _buffer A Buffer structure representing a CBOR-encoded value.
  /// @return A `CBOR` instance containing a partially decoded value.
  function _valueFromBuffer(WitnetBuffer.Buffer memory _buffer)
    private pure
    notEmpty(_buffer)
    returns (CBOR memory)
  {
    uint8 _initialByte;
    uint8 _majorType = 255;
    uint8 _additionalInformation;
    uint64 _tag = _UINT64_MAX;

    bool _isTagged = true;
    while (_isTagged) {
      // Extract basic CBOR properties from input bytes
      _initialByte = _buffer.readUint8();
      _majorType = _initialByte >> 5;
      _additionalInformation = _initialByte & 0x1f;
      // Early CBOR tag parsing.
      if (_majorType == 6) {
        _tag = _readLength(_buffer, _additionalInformation);
      } else {
        _isTagged = false;
      }
    }
    if (_majorType > 7) {
      revert UnsupportedMajorType(_majorType);
    }
    return CBOR(
      _buffer,
      _initialByte,
      _majorType,
      _additionalInformation,
      0,
      _tag
    );
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
      return _UINT64_MAX;
    }
    _length = _readLength(
      _buffer,
      _initialByte & 0x1f
    );
    if (_length >= _UINT64_MAX) {
      revert InvalidLengthEncoding(_length);
    } else if (_majorType != (_initialByte >> 5)) {
      revert UnexpectedMajorType((_initialByte >> 5), _majorType);
    }
  }

  /// Reads the length of the next CBOR item from a buffer, consuming a different number of bytes depending on the
  /// value of the `additionalInformation` argument.
  function _readLength(
      WitnetBuffer.Buffer memory _buffer,
      uint8 _additionalInformation
    )
    private pure
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
      return _UINT64_MAX;
    }
    revert InvalidLengthEncoding(_additionalInformation);
  }

  function _seekNext(WitnetCBOR.CBOR memory _cbor)
    private pure
    returns (WitnetCBOR.CBOR memory)
  {
    if (_cbor.majorType == 0 || _cbor.majorType == 1) {
      return _skipInt(_cbor);
    } else if (_cbor.majorType == 2) {
      return _skipBytes(_cbor);
    } else if (_cbor.majorType == 3) {
      return _skipText(_cbor);
    } else if (_cbor.majorType == 4) {
      return _skipArray(_cbor);
    } else if (_cbor.majorType == 7) {
      return _skipPrimitive(_cbor);
    } else {
      revert UnsupportedMajorType(_cbor.majorType);
    }
  }

  function _skipArray(CBOR memory _cbor)
    private pure
    isMajorType(_cbor, MajorTypes.Array)
    returns (CBOR memory)
  {
    CBOR[] memory _items = readArray(_cbor);
    if (_items.length > 0) {
      return _seekNext(_items[_items.length - 1]);
    } else {
      revert EmptyArray();
    }
  }

  function _skipBytes(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MajorTypes.Bytes)
    returns (CBOR memory)
  {
    _cbor.len = _readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_cbor.len < _UINT32_MAX) {
      _cbor.buffer.seek(_cbor.len);
      return _valueFromBuffer(_cbor.buffer);
    } 
    // TODO: support skipping indefitine length bytes array
    revert InvalidLengthEncoding(_cbor.len);
  }

  function _skipInt(CBOR memory _cbor)
    private pure
    returns (CBOR memory)
  {
    if (_cbor.majorType == 0 || _cbor.majorType == 1) {
      uint _offset = 1;
      if (_cbor.additionalInformation >= 24) {
        if (_cbor.additionalInformation <= 27) {
          _offset += 1 << (_cbor.additionalInformation - 24);
        } else {
          revert InvalidLengthEncoding(_cbor.additionalInformation);
        }
      } 
      _cbor.buffer.seek(_offset);
      return _valueFromBuffer(_cbor.buffer);
    } else {
      revert UnexpectedMajorType(_cbor.majorType, 1);
    }
  }

  function _skipPrimitive(CBOR memory _cbor)
    private pure
    isMajorType(_cbor, MajorTypes.Primitive)
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
    return _valueFromBuffer(_cbor.buffer);
  }

  function _skipText(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MajorTypes.String)
    returns (CBOR memory)
  {
    _cbor.len = _readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_cbor.len < _UINT64_MAX) {
      _cbor.buffer.seek(_cbor.len);
      return _valueFromBuffer(_cbor.buffer);
    }
    // TODO: support skipping indefitine length text array
    revert InvalidLengthEncoding(_cbor.len);  
  }

  function readArray(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MajorTypes.Array)
    returns (CBOR[] memory _items)
  {
    uint64 _length = _readLength(_cbor.buffer, _cbor.additionalInformation);
    _items = new CBOR[](_length);
    for (uint _ix = 0; _ix < _length; _ix ++) {
      _items[_ix] = _valueFromBuffer(_cbor.buffer);
      _cbor = _seekNext(_items[_ix]);
    }
  }

  function _replaceWildcards(CBOR memory _cbor, string[] memory _args)
    private pure
    isMajorType(_cbor, MajorTypes.String)
    returns (CBOR memory)
  {
    CBOR memory _copy = _valueFromBuffer(_cbor.buffer);
    _copy.buffer.replaceWildcards(
      _readLength(_copy.buffer, _copy.additionalInformation),
      _args
    );
    return _cbor;
  }

  function replaceWildcards(CBOR[] memory _items, string[] memory _args)
    internal pure
  {
    for (uint _ix = 0; _ix < _items.length; _ix ++) {
      if (_items[_ix].majorType == 4) {
        replaceWildcards(readArray(_items[_ix]), _args);
      } else if (_items[_ix].majorType == 3) {
        _replaceWildcards(_items[_ix], _args);
      }
    }
  }

  /// @notice Read a `CBOR` structure into a native `bool` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return The value represented by the input, as a `bool` value.
  function readBool(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MajorTypes.Primitive)
    returns (bool)
  {
    // uint64 _primitive = _readLength(_cbor.buffer, _cbor.additionalInformation);
    // if (_primitive == 20) {
    //   return false;
    // } else if (_primitive == 21) {
    //   return true;
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
    isMajorType(_cbor, MajorTypes.Bytes)
    returns (bytes memory _output)
  {
    _cbor.len = _readLength(
      _cbor.buffer,
      _cbor.additionalInformation
    );
    if (_cbor.len == _UINT32_MAX) {
      // These checks look repetitive but the equivalent loop would be more expensive.
      uint32 _length = uint32(_readIndefiniteStringLength(
        _cbor.buffer,
        _cbor.majorType
      ));
      if (_length < _UINT32_MAX) {
        _output = abi.encodePacked(_cbor.buffer.read(_length));
        _length = uint32(_readIndefiniteStringLength(
          _cbor.buffer,
          _cbor.majorType
        ));
        if (_length < _UINT32_MAX) {
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
    isMajorType(_cbor, MajorTypes.Primitive)
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
    isMajorType(_cbor, MajorTypes.Array)
    returns (int32[] memory _values)
  {
    uint64 _length = _readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < _UINT64_MAX) {
      _values = new int32[](_length);
      for (uint64 _i = 0; _i < _length; ) {
        CBOR memory _item = _valueFromBuffer(_cbor.buffer);
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
      uint64 _value = _readLength(
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
    isMajorType(_cbor, MajorTypes.Array)
    returns (int[] memory _array)
  {
    uint64 _length = _readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < _UINT64_MAX) {
      _array = new int[](_length);
      for (uint _i = 0; _i < _length; ) {
        CBOR memory _item = _valueFromBuffer(_cbor.buffer);
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
    isMajorType(_cbor, MajorTypes.String)
    returns (string memory _text)
  {
    _cbor.len = _readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_cbor.len == _UINT64_MAX) {
      bool _done;
      while (!_done) {
        uint64 _length = _readIndefiniteStringLength(
          _cbor.buffer,
          _cbor.majorType
        );
        if (_length < _UINT64_MAX) {
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
    isMajorType(_cbor, MajorTypes.Array)
    returns (string[] memory _strings)
  {
    uint _length = _readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < _UINT64_MAX) {
      _strings = new string[](_length);
      for (uint _i = 0; _i < _length; ) {
        CBOR memory _item = _valueFromBuffer(_cbor.buffer);
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
    isMajorType(_cbor, MajorTypes.Uint)
    returns (uint)
  {
    return _readLength(
      _cbor.buffer,
      _cbor.additionalInformation
    );
  }

  /// @notice Decode a `CBOR` structure into a native `uint64[]` value.
  /// @param _cbor An instance of `CBOR`.
  /// @return _values The value represented by the input, as an `uint64[]` value.
  function readUintArray(CBOR memory _cbor)
    internal pure
    isMajorType(_cbor, MajorTypes.Array)
    returns (uint[] memory _values)
  {
    uint64 _length = _readLength(_cbor.buffer, _cbor.additionalInformation);
    if (_length < _UINT64_MAX) {
      _values = new uint[](_length);
      for (uint _ix = 0; _ix < _length; ) {
        CBOR memory _item = _valueFromBuffer(_cbor.buffer);
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