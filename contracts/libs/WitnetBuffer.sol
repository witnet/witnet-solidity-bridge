// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title A convenient wrapper around the `bytes memory` type that exposes a buffer-like interface
/// @notice The buffer has an inner cursor that tracks the final offset of every read, i.e. any subsequent read will
/// start with the byte that goes right after the last one in the previous read.
/// @dev `uint32` is used here for `cursor` because `uint16` would only enable seeking up to 8KB, which could in some
/// theoretical use cases be exceeded. Conversely, `uint32` supports up to 512MB, which cannot credibly be exceeded.
/// @author The Witnet Foundation.
library WitnetBuffer {

  error EmptyBuffer();
  error IndexOutOfBounds(uint index, uint range);

  /// Iterable bytes buffer.
  struct Buffer {
      bytes data;
      uint cursor;
  }

  // Ensures we access an existing index in an array
  modifier withinRange(uint _index, uint _range) {
    if (_index >= _range) {
      revert IndexOutOfBounds(_index, _range);
    }
    _;
  }

  /// @notice Read and consume a certain amount of bytes from the buffer.
  /// @param _buffer An instance of `Buffer`.
  /// @param _length How many bytes to read and consume from the buffer.
  /// @return _output A `bytes memory` containing the first `_length` bytes from the buffer, counting from the cursor position.
  function read(Buffer memory _buffer, uint _length)
    internal pure
    withinRange(_buffer.cursor + _length, _buffer.data.length + 1)
    returns (bytes memory _output)
  {
    // Create a new `bytes memory destination` value
    _output = new bytes(_length);
    // Early return in case that bytes length is 0
    if (_length > 0) {
      bytes memory _input = _buffer.data;
      uint _offset = _buffer.cursor;
      // Get raw pointers for source and destination
      uint _sourcePointer;
      uint _destinationPointer;
      assembly {
        _sourcePointer := add(add(_input, 32), _offset)
        _destinationPointer := add(_output, 32)
      }
      // Copy `_length` bytes from source to destination
      memcpy(
        _destinationPointer,
        _sourcePointer,
        _length
      );
      // Move the cursor forward by `_length` bytes
      seek(
        _buffer,
        _length,
        true
      );
    }
  }

  /// @notice Read and consume the next byte from the buffer.
  /// @param _buffer An instance of `Buffer`.
  /// @return The next byte in the buffer counting from the cursor position.
  function next(Buffer memory _buffer)
    internal pure
    withinRange(_buffer.cursor, _buffer.data.length)
    returns (bytes1)
  {
    // Return the byte at the position marked by the cursor and advance the cursor all at once
    return _buffer.data[_buffer.cursor ++];
  }

  function mutate(
      WitnetBuffer.Buffer memory _buffer,
      uint _length,
      bytes memory _genes
    )
    internal pure
    withinRange(_length, _buffer.data.length - _buffer.cursor)
  {
    // TODO
  }

  // @notice Extract bytes array from buffer starting from current cursor.
  /// @param _buffer An instance of `Buffer`.
  /// @param _length How many bytes to peek from the Buffer.
  // solium-disable-next-line security/no-assign-params
  function peek(
      WitnetBuffer.Buffer memory _buffer,
      uint _length
    )
    internal pure
    withinRange(_length, _buffer.data.length - _buffer.cursor)
    returns (bytes memory)
  {
    bytes memory _data = _buffer.data;
    bytes memory _peek = new bytes(_length);
    uint _offset = _buffer.cursor;
    uint _destinationPointer;
    uint _sourcePointer;
    assembly {
      _destinationPointer := add(_peek, 32)
      _sourcePointer := add(add(_data, 32), _offset)
    }
    memcpy(
      _destinationPointer,
      _sourcePointer,
      _length
    );
    return _peek;
  }

  /// @notice Move the inner cursor of the buffer to a relative or absolute position.
  /// @param _buffer An instance of `Buffer`.
  /// @param _offset How many bytes to move the cursor forward.
  /// @param _relative Whether to count `_offset` from the last position of the cursor (`true`) or the beginning of the
  /// buffer (`true`).
  /// @return The final position of the cursor (will equal `_offset` if `_relative` is `false`).
  // solium-disable-next-line security/no-assign-params
  function seek(
      Buffer memory _buffer,
      uint _offset,
      bool _relative
    )
    internal pure
    withinRange(_offset, _buffer.data.length + 1)
    returns (uint)
  {
    // Deal with relative offsets
    if (_relative) {
      _offset += _buffer.cursor;
    }
    _buffer.cursor = _offset;
    return _offset;
  }

  /// @notice Move the inner cursor a number of bytes forward.
  /// @dev This is a simple wrapper around the relative offset case of `seek()`.
  /// @param _buffer An instance of `Buffer`.
  /// @param _relativeOffset How many bytes to move the cursor forward.
  /// @return The final position of the cursor.
  function seek(
      Buffer memory _buffer,
      uint _relativeOffset
    )
    internal pure
    returns (uint)
  {
    return seek(
      _buffer,
      _relativeOffset,
      true
    );
  }

  /// @notice Move the inner cursor back to the first byte in the buffer.
  /// @param _buffer An instance of `Buffer`.
  function rewind(Buffer memory _buffer)
    internal pure
  {
    _buffer.cursor = 0;
  }
  
  /// @notice Read and consume the next 2 bytes from the buffer as an IEEE 754-2008 floating point number enclosed in an
  /// `int32`.
  /// @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values
  /// by 5 decimal orders so as to get a fixed precision of 5 decimal positions, which should be OK for most `float16`
  /// use cases. In other words, the integer output of this method is 10,000 times the actual value. The input bytes are
  /// expected to follow the 16-bit base-2 format (a.k.a. `binary16`) in the IEEE 754-2008 standard.
  /// @param _buffer An instance of `Buffer`.
  /// @return _result The `int32` value of the next 4 bytes in the buffer counting from the cursor position.
  function readFloat16(Buffer memory _buffer)
    internal pure
    returns (int32 _result)
  {
    uint32 _value = readUint16(_buffer);
    // Get bit at position 0
    uint32 _sign = _value & 0x8000;
    // Get bits 1 to 5, then normalize to the [-14, 15] range so as to counterweight the IEEE 754 exponent bias
    int32 _exponent = (int32(_value & 0x7c00) >> 10) - 15;
    // Get bits 6 to 15
    int32 _significand = int32(_value & 0x03ff);
    // Add 1024 to the fraction if the exponent is 0
    if (_exponent == 15) {
      _significand |= 0x400;
    }
    // Compute `2 ^ exponent · (1 + fraction / 1024)`
    if (_exponent >= 0) {
      _result = (
        int32((int256(1 << uint256(int256(_exponent)))
          * 10000
          * int256(uint256(int256(_significand)) | 0x400)) >> 10)
      );
    } else {
      _result = (int32(
        ((int256(uint256(int256(_significand)) | 0x400) * 10000)
          / int256(1 << uint256(int256(- _exponent))))
          >> 10
      ));
    }
    // Make the result negative if the sign bit is not 0
    if (_sign != 0) {
      _result *= -1;
    }
  }

  // Read a text string of a given length from a buffer. Returns a `bytes memory` value for the sake of genericness,
  /// but it can be easily casted into a string with `string(result)`.
  // solium-disable-next-line security/no-assign-params
  function readText(
      WitnetBuffer.Buffer memory _buffer,
      uint64 _length
    )
    internal pure
    returns (bytes memory _text)
  {
    _text = new bytes(_length);
    unchecked {
      for (uint64 _index = 0; _index < _length; _index ++) {
        uint8 _char = readUint8(_buffer);
        if (_char & 0x80 != 0) {
          if (_char < 0xe0) {
            _char = (_char & 0x1f) << 6
              | (readUint8(_buffer) & 0x3f);
            _length -= 1;
          } else if (_char < 0xf0) {
            _char  = (_char & 0x0f) << 12
              | (readUint8(_buffer) & 0x3f) << 6
              | (readUint8(_buffer) & 0x3f);
            _length -= 2;
          } else {
            _char = (_char & 0x0f) << 18
              | (readUint8(_buffer) & 0x3f) << 12
              | (readUint8(_buffer) & 0x3f) << 6  
              | (readUint8(_buffer) & 0x3f);
            _length -= 3;
          }
        }
        _text[_index] = bytes1(_char);
      }
      // Adjust text to actual length:
      assembly {
        mstore(_text, _length)
      }
    }
  }

  /// @notice Read and consume the next byte from the buffer as an `uint8`.
  /// @param _buffer An instance of `Buffer`.
  /// @return _value The `uint8` value of the next byte in the buffer counting from the cursor position.
  function readUint8(Buffer memory _buffer)
    internal pure
    withinRange(_buffer.cursor, _buffer.data.length)
    returns (uint8 _value)
  {
    bytes memory _data = _buffer.data;
    uint _offset = _buffer.cursor;
    assembly {
      _value := mload(add(add(_data, 1), _offset))
    }
    _buffer.cursor ++;
  }

  /// @notice Read and consume the next 2 bytes from the buffer as an `uint16`.
  /// @param _buffer An instance of `Buffer`.
  /// @return _value The `uint16` value of the next 2 bytes in the buffer counting from the cursor position.
  function readUint16(Buffer memory _buffer)
    internal pure
    withinRange(_buffer.cursor + 1, _buffer.data.length)
    returns (uint16 _value)
  {
    bytes memory _data = _buffer.data;
    uint _offset = _buffer.cursor;
    assembly {
      _value := mload(add(add(_data, 2), _offset))
    }
    _buffer.cursor += 2;
  }

  /// @notice Read and consume the next 4 bytes from the buffer as an `uint32`.
  /// @param _buffer An instance of `Buffer`.
  /// @return _value The `uint32` value of the next 4 bytes in the buffer counting from the cursor position.
  function readUint32(Buffer memory _buffer)
    internal pure
    withinRange(_buffer.cursor + 3, _buffer.data.length)
    returns (uint32 _value)
  {
    bytes memory _data = _buffer.data;
    uint _offset = _buffer.cursor;
    assembly {
      _value := mload(add(add(_data, 4), _offset))
    }
    _buffer.cursor += 4;
  }

  /// @notice Read and consume the next 8 bytes from the buffer as an `uint64`.
  /// @param _buffer An instance of `Buffer`.
  /// @return _value The `uint64` value of the next 8 bytes in the buffer counting from the cursor position.
  function readUint64(Buffer memory _buffer)
    internal pure
    withinRange(_buffer.cursor + 7, _buffer.data.length)
    returns (uint64 _value)
  {
    bytes memory _data = _buffer.data;
    uint _offset = _buffer.cursor;
    assembly {
      _value := mload(add(add(_data, 8), _offset))
    }
    _buffer.cursor += 8;
  }

  /// @notice Read and consume the next 16 bytes from the buffer as an `uint128`.
  /// @param _buffer An instance of `Buffer`.
  /// @return _value The `uint128` value of the next 16 bytes in the buffer counting from the cursor position.
  function readUint128(Buffer memory _buffer)
    internal pure
    withinRange(_buffer.cursor + 15, _buffer.data.length)
    returns (uint128 _value)
  {
    bytes memory _data = _buffer.data;
    uint _offset = _buffer.cursor;
    assembly {
      _value := mload(add(add(_data, 16), _offset))
    }
    _buffer.cursor += 16;
  }

  /// @notice Read and consume the next 32 bytes from the buffer as an `uint256`.
  /// @param _buffer An instance of `Buffer`.
  /// @return _value The `uint256` value of the next 32 bytes in the buffer counting from the cursor position.
  function readUint256(Buffer memory _buffer)
    internal pure
    withinRange(_buffer.cursor + 31, _buffer.data.length)
    returns (uint256 _value)
  {
    bytes memory _data = _buffer.data;
    uint _offset = _buffer.cursor;
    assembly {
      _value := mload(add(add(_data, 32), _offset))
    }
    _buffer.cursor += 32;
  }

  /// @notice Copy bytes from one memory address into another.
  /// @dev This function was borrowed from Nick Johnson's `solidity-stringutils` lib, and reproduced here under the terms
  /// of [Apache License 2.0](https://github.com/Arachnid/solidity-stringutils/blob/master/LICENSE).
  /// @param _dest Address of the destination memory.
  /// @param _src Address to the source memory.
  /// @param _len How many bytes to copy.
  // solium-disable-next-line security/no-assign-params
  function memcpy(
      uint _dest,
      uint _src,
      uint _len
    )
    internal pure
  {
    // Copy word-length chunks while possible
    for (; _len >= 32; _len -= 32) {
      assembly {
        mstore(_dest, mload(_src))
      }
      _dest += 32;
      _src += 32;
    }
    if (_len > 0) {
      // Copy remaining bytes
      uint _mask = 256 ** (32 - _len) - 1;
      assembly {
        let _srcpart := and(mload(_src), not(_mask))
        let _destpart := and(mload(_dest), _mask)
        mstore(_dest, or(_destpart, _srcpart))
      }
    }
  }

  function concat(bytes[] memory _buffs)
    internal pure
    returns (bytes memory _output)
  {
    unchecked {
      uint _ix;
      uint _destinationPointer;
      assembly {
        _destinationPointer := add(_output, 32)
      }
      while (_ix < _buffs.length) {        
        bytes memory _source = _buffs[_ix];
        uint _sourceLength = _source.length;
        uint _sourcePointer;        
        assembly {
          // sets source memory pointer
          _sourcePointer := add(_source, 32)
        }
        memcpy(
          _destinationPointer,
          _sourcePointer,
          _sourceLength
        );
        assembly {
          // increase _output size
          mstore(_output, add(mload(_output), _sourceLength))
          // sets destination memory pointer
          _destinationPointer := add(_destinationPointer, _sourceLength)
        }
        _ix ++;
      }
    }
  }

  function replaceWildcards(
      WitnetBuffer.Buffer memory _buffer,
      uint _length,
      string[] memory _args
    )
    internal pure
  {
    bytes memory _peek = replaceWildcards(
      peek(_buffer, _length),
      _args
    );
    if (_peek.length != _length) {
      mutate(_buffer, _length, _peek);
    }
  }

  /// @notice Replace bytecode indexed wildcards by correspondent string.
  /// @dev Wildcard format: "\#\", with # in ["0".."9"].
  /// @param _input Bytes array containing strings.
  /// @param _args String values for replacing existing indexed wildcards in _input.
  function replaceWildcards(bytes memory _input, string[] memory _args)
      internal pure
      returns (bytes memory _output)
  {
    _output = _input;
    if (_input.length >= 3) {
      uint _outputLength = _input.length;
      unchecked {                
        // scan for wildcards as to calculate output length:
        for (uint _ix = 0; _ix < _input.length - 2; ) {
          if (_input[_ix] == bytes1("\\")) {
            if (_input[_ix + 2] == bytes1("\\")) {
              if (_input[_ix + 1] >= bytes1("0") && _input[_ix + 1] <= bytes1("9")) {
                uint _argIndex = uint(uint8(_input[_ix + 1]) - uint8(bytes1("0")));
                assert(_args.length >= uint(_argIndex) + 1);
                _outputLength += bytes(_args[_argIndex]).length - 3;
                _ix += 3;
              } else {
                _ix += 2;
              }
              continue;
            } else {
              _ix += 3;
              continue;
            }
          } else {
            _ix ++;
          }
        }
        // if wildcards found:
        if (_outputLength > _input.length) {
          _output = new bytes(_outputLength);
          // Replace indexed wildcards:
          for (uint _ix = 0; _ix < _input.length - 2; ) {
            if (_input[_ix] == bytes1("\\")) {
              if (_input[_ix + 2] == bytes1("\\")) {
                if (_input[_ix + 1] >= bytes1("0") && _input[_ix + 1] <= bytes1("9")) {
                  uint _argIndex = uint(uint8(_input[_ix + 1]) - uint8(bytes1("0")));
                  for (uint _ax = 0; _ax < bytes(_args[_argIndex]).length; _ax ++) {
                    _output[_ix + _ax] = bytes(_args[_argIndex])[_ax];
                  }
                  _ix += 3;
                  continue;
                }
              }
            }
            _output[_ix] = _input[_ix ++];
          }
        }
      }
    }
  }

}