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
  error MissingArgs(uint expected, uint given);

  /// Iterable bytes buffer.
  struct Buffer {
      bytes data;
      uint cursor;
  }

  // Ensures we access an existing index in an array
  modifier withinRange(uint index, uint _range) {
    if (index > _range) {
      revert IndexOutOfBounds(index, _range);
    }
    _;
  }

  /// @notice Concatenate undefinite number of bytes chunks.
  /// @dev Faster than looping on `abi.encodePacked(output, _buffs[ix])`.
  function concat(bytes[] memory _buffs)
    internal pure
    returns (bytes memory output)
  {
    unchecked {
      uint destinationPointer;
      uint destinationLength;
      assembly {
        // get safe scratch location
        output := mload(0x40)
        // set starting destination pointer
        destinationPointer := add(output, 32)
      }      
      for (uint ix = 1; ix <= _buffs.length; ix ++) {  
        uint source;
        uint sourceLength;
        uint sourcePointer;        
        assembly {
          // load source length pointer
          source := mload(add(_buffs, mul(ix, 32)))
          // load source length
          sourceLength := mload(source)
          // sets source memory pointer
          sourcePointer := add(source, 32)
        }
        memcpy(
          destinationPointer,
          sourcePointer,
          sourceLength
        );
        assembly {          
          // increase total destination length
          destinationLength := add(destinationLength, sourceLength)
          // sets destination memory pointer
          destinationPointer := add(destinationPointer, sourceLength)
        }
      }
      assembly {
        // protect output bytes
        mstore(output, destinationLength)
        // set final output length
        mstore(0x40, add(mload(0x40), add(destinationLength, 32)))
      }
    }
  }

  function fork(WitnetBuffer.Buffer memory buffer)
    internal pure
    returns (WitnetBuffer.Buffer memory)
  {
    return Buffer(
      buffer.data,
      buffer.cursor
    );
  }

  function mutate(
      WitnetBuffer.Buffer memory buffer,
      uint length,
      bytes memory pokes
    )
    internal pure
    withinRange(length, buffer.data.length - buffer.cursor + 1)
  {
    bytes[] memory parts = new bytes[](3);
    parts[0] = peek(
      buffer,
      0,
      buffer.cursor
    );
    parts[1] = pokes;
    parts[2] = peek(
      buffer,
      buffer.cursor + length,
      buffer.data.length - buffer.cursor - length
    );
    buffer.data = concat(parts);
  }

  /// @notice Read and consume the next byte from the buffer.
  /// @param buffer An instance of `Buffer`.
  /// @return The next byte in the buffer counting from the cursor position.
  function next(Buffer memory buffer)
    internal pure
    withinRange(buffer.cursor, buffer.data.length)
    returns (bytes1)
  {
    // Return the byte at the position marked by the cursor and advance the cursor all at once
    return buffer.data[buffer.cursor ++];
  }

  function peek(
      WitnetBuffer.Buffer memory buffer,
      uint offset,
      uint length
    )
    internal pure
    withinRange(offset + length, buffer.data.length)
    returns (bytes memory)
  {
    bytes memory data = buffer.data;
    bytes memory peeks = new bytes(length);
    uint destinationPointer;
    uint sourcePointer;
    assembly {
      destinationPointer := add(peeks, 32)
      sourcePointer := add(add(data, 32), offset)
    }
    memcpy(
      destinationPointer,
      sourcePointer,
      length
    );
    return peeks;
  }

  // @notice Extract bytes array from buffer starting from current cursor.
  /// @param buffer An instance of `Buffer`.
  /// @param length How many bytes to peek from the Buffer.
  // solium-disable-next-line security/no-assign-params
  function peek(
      WitnetBuffer.Buffer memory buffer,
      uint length
    )
    internal pure
    withinRange(length, buffer.data.length - buffer.cursor)
    returns (bytes memory)
  {
    return peek(
      buffer,
      buffer.cursor,
      length
    );
  }

  /// @notice Read and consume a certain amount of bytes from the buffer.
  /// @param buffer An instance of `Buffer`.
  /// @param length How many bytes to read and consume from the buffer.
  /// @return output A `bytes memory` containing the first `length` bytes from the buffer, counting from the cursor position.
  function read(Buffer memory buffer, uint length)
    internal pure
    withinRange(buffer.cursor + length, buffer.data.length)
    returns (bytes memory output)
  {
    // Create a new `bytes memory destination` value
    output = new bytes(length);
    // Early return in case that bytes length is 0
    if (length > 0) {
      bytes memory input = buffer.data;
      uint offset = buffer.cursor;
      // Get raw pointers for source and destination
      uint sourcePointer;
      uint destinationPointer;
      assembly {
        sourcePointer := add(add(input, 32), offset)
        destinationPointer := add(output, 32)
      }
      // Copy `length` bytes from source to destination
      memcpy(
        destinationPointer,
        sourcePointer,
        length
      );
      // Move the cursor forward by `length` bytes
      seek(
        buffer,
        length,
        true
      );
    }
  }
  
  /// @notice Read and consume the next 2 bytes from the buffer as an IEEE 754-2008 floating point number enclosed in an
  /// `int32`.
  /// @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values
  /// by 5 decimal orders so as to get a fixed precision of 5 decimal positions, which should be OK for most `float16`
  /// use cases. In other words, the integer output of this method is 10,000 times the actual value. The input bytes are
  /// expected to follow the 16-bit base-2 format (a.k.a. `binary16`) in the IEEE 754-2008 standard.
  /// @param buffer An instance of `Buffer`.
  /// @return result The `int32` value of the next 4 bytes in the buffer counting from the cursor position.
  function readFloat16(Buffer memory buffer)
    internal pure
    returns (int32 result)
  {
    uint32 value = readUint16(buffer);
    // Get bit at position 0
    uint32 sign = value & 0x8000;
    // Get bits 1 to 5, then normalize to the [-15, 16] range so as to counterweight the IEEE 754 exponent bias
    int32 exponent = (int32(value & 0x7c00) >> 10) - 15;
    // Get bits 6 to 15
    int32 fraction = int32(value & 0x03ff);
    // Add 2^10 to the fraction if exponent is not -15
    if (exponent != -15) {
      fraction |= 0x400;
    } else if (exponent == 16) {
      revert(
        string(abi.encodePacked(
          "WitnetBuffer.readFloat16: ",
          sign != 0 ? "negative" : hex"",
          " infinity"
        ))
      );
    }
    // Compute `2 ^ exponent · (1 + fraction / 1024)`
    if (exponent >= 0) {
      result = int32(int(
        int(1 << uint256(int256(exponent)))
          * 10000
          * fraction
      ) >> 10);
    } else {
      result = int32(int(
        int(fraction)
          * 10000
          / int(1 << uint(int(- exponent)))
      ) >> 10);
    }
    // Make the result negative if the sign bit is not 0
    if (sign != 0) {
      result *= -1;
    }
  }

  /// @notice Consume the next 4 bytes from the buffer as an IEEE 754-2008 floating point number enclosed into an `int`.
  /// @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values
  /// by 9 decimal orders so as to get a fixed precision of 9 decimal positions, which should be OK for most `float32`
  /// use cases. In other words, the integer output of this method is 10^9 times the actual value. The input bytes are
  /// expected to follow the 64-bit base-2 format (a.k.a. `binary32`) in the IEEE 754-2008 standard.
  /// @param buffer An instance of `Buffer`.
  /// @return result The `int` value of the next 8 bytes in the buffer counting from the cursor position.
  function readFloat32(Buffer memory buffer)
    internal pure
    returns (int result)
  {
    uint value = readUint32(buffer);
    // Get bit at position 0
    uint sign = value & 0x80000000;
    // Get bits 1 to 8, then normalize to the [-127, 128] range so as to counterweight the IEEE 754 exponent bias
    int exponent = (int(value & 0x7f800000) >> 23) - 127;
    // Get bits 9 to 31
    int fraction = int(value & 0x007fffff);
    // Add 2^23 to the fraction if exponent is not -127
    if (exponent != -127) {
      fraction |= 0x800000;
    } else if (exponent == 128) {
      revert(
        string(abi.encodePacked(
          "WitnetBuffer.readFloat32: ",
          sign != 0 ? "negative" : hex"",
          " infinity"
        ))
      );
    }
    // Compute `2 ^ exponent · (1 + fraction / 2^23)`
    if (exponent >= 0) {
      result = (
        int(1 << uint(exponent))
          * (10 ** 9)
          * fraction
      ) >> 23;
    } else {
      result = (
        fraction 
          * (10 ** 9)
          / int(1 << uint(-exponent)) 
      ) >> 23;
    }
    // Make the result negative if the sign bit is not 0
    if (sign != 0) {
      result *= -1;
    }
  }

  /// @notice Consume the next 8 bytes from the buffer as an IEEE 754-2008 floating point number enclosed into an `int`.
  /// @dev Due to the lack of support for floating or fixed point arithmetic in the EVM, this method offsets all values
  /// by 15 decimal orders so as to get a fixed precision of 15 decimal positions, which should be OK for most `float64`
  /// use cases. In other words, the integer output of this method is 10^15 times the actual value. The input bytes are
  /// expected to follow the 64-bit base-2 format (a.k.a. `binary64`) in the IEEE 754-2008 standard.
  /// @param buffer An instance of `Buffer`.
  /// @return result The `int` value of the next 8 bytes in the buffer counting from the cursor position.
  function readFloat64(Buffer memory buffer)
    internal pure
    returns (int result)
  {
    uint value = readUint64(buffer);
    // Get bit at position 0
    uint sign = value & 0x8000000000000000;
    // Get bits 1 to 12, then normalize to the [-1023, 1024] range so as to counterweight the IEEE 754 exponent bias
    int exponent = (int(value & 0x7ff0000000000000) >> 52) - 1023;
    // Get bits 6 to 15
    int fraction = int(value & 0x000fffffffffffff);
    // Add 2^52 to the fraction if exponent is not -1023
    if (exponent != -1023) {
      fraction |= 0x10000000000000;
    } else if (exponent == 1024) {
      revert(
        string(abi.encodePacked(
          "WitnetBuffer.readFloat64: ",
          sign != 0 ? "negative" : hex"",
          " infinity"
        ))
      );
    }
    // Compute `2 ^ exponent · (1 + fraction / 1024)`
    if (exponent >= 0) {
      result = (
        int(1 << uint(exponent))
          * (10 ** 15)
          * fraction
      ) >> 52;
    } else {
      result = (
        fraction 
          * (10 ** 15)
          / int(1 << uint(-exponent)) 
      ) >> 52;
    }
    // Make the result negative if the sign bit is not 0
    if (sign != 0) {
      result *= -1;
    }
  }

  // Read a text string of a given length from a buffer. Returns a `bytes memory` value for the sake of genericness,
  /// but it can be easily casted into a string with `string(result)`.
  // solium-disable-next-line security/no-assign-params
  function readText(
      WitnetBuffer.Buffer memory buffer,
      uint64 length
    )
    internal pure
    returns (bytes memory text)
  {
    text = new bytes(length);
    unchecked {
      for (uint64 index = 0; index < length; index ++) {
        uint8 char = readUint8(buffer);
        if (char & 0x80 != 0) {
          if (char < 0xe0) {
            char = (char & 0x1f) << 6
              | (readUint8(buffer) & 0x3f);
            length -= 1;
          } else if (char < 0xf0) {
            char  = (char & 0x0f) << 12
              | (readUint8(buffer) & 0x3f) << 6
              | (readUint8(buffer) & 0x3f);
            length -= 2;
          } else {
            char = (char & 0x0f) << 18
              | (readUint8(buffer) & 0x3f) << 12
              | (readUint8(buffer) & 0x3f) << 6  
              | (readUint8(buffer) & 0x3f);
            length -= 3;
          }
        }
        text[index] = bytes1(char);
      }
      // Adjust text to actual length:
      assembly {
        mstore(text, length)
      }
    }
  }

  /// @notice Read and consume the next byte from the buffer as an `uint8`.
  /// @param buffer An instance of `Buffer`.
  /// @return value The `uint8` value of the next byte in the buffer counting from the cursor position.
  function readUint8(Buffer memory buffer)
    internal pure
    withinRange(buffer.cursor, buffer.data.length)
    returns (uint8 value)
  {
    bytes memory data = buffer.data;
    uint offset = buffer.cursor;
    assembly {
      value := mload(add(add(data, 1), offset))
    }
    buffer.cursor ++;
  }

  /// @notice Read and consume the next 2 bytes from the buffer as an `uint16`.
  /// @param buffer An instance of `Buffer`.
  /// @return value The `uint16` value of the next 2 bytes in the buffer counting from the cursor position.
  function readUint16(Buffer memory buffer)
    internal pure
    withinRange(buffer.cursor + 2, buffer.data.length)
    returns (uint16 value)
  {
    bytes memory data = buffer.data;
    uint offset = buffer.cursor;
    assembly {
      value := mload(add(add(data, 2), offset))
    }
    buffer.cursor += 2;
  }

  /// @notice Read and consume the next 4 bytes from the buffer as an `uint32`.
  /// @param buffer An instance of `Buffer`.
  /// @return value The `uint32` value of the next 4 bytes in the buffer counting from the cursor position.
  function readUint32(Buffer memory buffer)
    internal pure
    withinRange(buffer.cursor + 4, buffer.data.length)
    returns (uint32 value)
  {
    bytes memory data = buffer.data;
    uint offset = buffer.cursor;
    assembly {
      value := mload(add(add(data, 4), offset))
    }
    buffer.cursor += 4;
  }

  /// @notice Read and consume the next 8 bytes from the buffer as an `uint64`.
  /// @param buffer An instance of `Buffer`.
  /// @return value The `uint64` value of the next 8 bytes in the buffer counting from the cursor position.
  function readUint64(Buffer memory buffer)
    internal pure
    withinRange(buffer.cursor + 8, buffer.data.length)
    returns (uint64 value)
  {
    bytes memory data = buffer.data;
    uint offset = buffer.cursor;
    assembly {
      value := mload(add(add(data, 8), offset))
    }
    buffer.cursor += 8;
  }

  /// @notice Read and consume the next 16 bytes from the buffer as an `uint128`.
  /// @param buffer An instance of `Buffer`.
  /// @return value The `uint128` value of the next 16 bytes in the buffer counting from the cursor position.
  function readUint128(Buffer memory buffer)
    internal pure
    withinRange(buffer.cursor + 16, buffer.data.length)
    returns (uint128 value)
  {
    bytes memory data = buffer.data;
    uint offset = buffer.cursor;
    assembly {
      value := mload(add(add(data, 16), offset))
    }
    buffer.cursor += 16;
  }

  /// @notice Read and consume the next 32 bytes from the buffer as an `uint256`.
  /// @param buffer An instance of `Buffer`.
  /// @return value The `uint256` value of the next 32 bytes in the buffer counting from the cursor position.
  function readUint256(Buffer memory buffer)
    internal pure
    withinRange(buffer.cursor + 32, buffer.data.length)
    returns (uint256 value)
  {
    bytes memory data = buffer.data;
    uint offset = buffer.cursor;
    assembly {
      value := mload(add(add(data, 32), offset))
    }
    buffer.cursor += 32;
  }

  /// @notice Count number of required parameters for given bytes arrays
  /// @dev Wildcard format: "\#\", with # in ["0".."9"].
  /// @param input Bytes array containing strings.
  /// @param count Highest wildcard index found, plus 1.
  function argsCountOf(bytes memory input)
    internal pure
    returns (uint8 count)
  {
    if (input.length < 3) {
      return 0;
    }
    unchecked {
      uint ix = 0; 
      uint length = input.length - 2;
      for (; ix < length; ) {
        if (
          input[ix] == bytes1("\\")
            && input[ix + 2] == bytes1("\\")
            && input[ix + 1] >= bytes1("0")
            && input[ix + 1] <= bytes1("9")
        ) {
          uint8 ax = uint8(uint8(input[ix + 1]) - uint8(bytes1("0")) + 1);
          if (ax > count) {
            count = ax;
          }
          ix += 3;
        } else {
          ix ++;
        }
      }
    }
  }

  /// @notice Replace indexed bytes-wildcards by correspondent substrings.
  /// @dev Wildcard format: "\#\", with # in ["0".."9"].
  /// @param input Bytes array containing strings.
  /// @param args Array of substring values for replacing indexed wildcards.
  /// @return output Resulting bytes array after replacing all wildcards.
  /// @return hits Total number of replaced wildcards.
  function replace(bytes memory input, string[] memory args)
    internal pure
    returns (bytes memory output, uint hits)
  {
    uint ix = 0; uint lix = 0;
    uint inputLength;
    uint inputPointer;
    uint outputLength;
    uint outputPointer;    
    uint source;
    uint sourceLength;
    uint sourcePointer;

    if (input.length < 3) {
      return (input, 0);
    }
    
    assembly {
      // set starting input pointer
      inputPointer := add(input, 32)
      // get safe output location
      output := mload(0x40)
      // set starting output pointer
      outputPointer := add(output, 32)
    }         

    unchecked {
      uint length = input.length - 2;
      for (; ix < length; ) {
        if (
          input[ix] == bytes1("\\")
            && input[ix + 2] == bytes1("\\")
            && input[ix + 1] >= bytes1("0")
            && input[ix + 1] <= bytes1("9")
        ) {
          inputLength = (ix - lix);
          if (ix > lix) {
            memcpy(
              outputPointer,
              inputPointer,
              inputLength
            );
            inputPointer += inputLength + 3;
            outputPointer += inputLength;
          } else {
            inputPointer += 3;
          }
          uint ax = uint(uint8(input[ix + 1]) - uint8(bytes1("0")));
          if (ax >= args.length) {
            revert MissingArgs(ax + 1, args.length);
          }
          assembly {
            source := mload(add(args, mul(32, add(ax, 1))))
            sourceLength := mload(source)
            sourcePointer := add(source, 32)      
          }        
          memcpy(
            outputPointer,
            sourcePointer,
            sourceLength
          );
          outputLength += inputLength + sourceLength;
          outputPointer += sourceLength;
          ix += 3;
          lix = ix;
          hits ++;
        } else {
          ix ++;
        }
      }
      ix = input.length;    
    }
    if (outputLength > 0) {
      if (ix > lix ) {
        memcpy(
          outputPointer,
          inputPointer,
          ix - lix
        );
        outputLength += (ix - lix);
      }
      assembly {
        // set final output length
        mstore(output, outputLength)
        // protect output bytes
        mstore(0x40, add(mload(0x40), add(outputLength, 32)))
      }
    }
    else {
      return (input, 0);
    }
  }

  /// @notice Replace indexed bytes-wildcard by given substring.
  /// @dev Wildcard format: "\#\", with # in ["0".."9"].
  /// @param input Bytes array containing strings.
  /// @param argIndex Index of the wildcard to be replaced.
  /// @param argValue Replacing substring to be used.
  /// @return output Resulting bytes array after replacing all wildcards.
  /// @return hits Total number of replaced wildcards.
  function replace(bytes memory input, uint8 argIndex, string memory argValue)
    internal pure
    returns (bytes memory output, uint hits)
  {
    uint ix = 0; uint lix = 0;
    uint inputLength;
    uint inputPointer;
    uint outputLength;
    uint outputPointer; 
    uint argValueLength;
    uint argValuePointer;

    if (input.length < 3) {
      return (input, 0);
    }
    
    assembly {
      // set starting input pointer
      inputPointer := add(input, 32)
      // get safe output location
      output := mload(0x40)
      // set starting output pointer
      outputPointer := add(output, 32)
      // set pointer to arg value substring
      argValuePointer := add(argValue, 32)
      // set arg value substring length
      argValueLength := mload(argValue)
    }         

    unchecked {
      uint length = input.length - 2;
      for (; ix < length; ) {
        if (
          input[ix] == bytes1("\\")
            && input[ix + 2] == bytes1("\\")
            && input[ix + 1] >= bytes1("0")
            && input[ix + 1] <= bytes1("9")
            && uint8(input[ix + 1]) - uint8(bytes1("0")) == argIndex
        ) {
          inputLength = (ix - lix);
          if (ix > lix) {
            memcpy(
              outputPointer,
              inputPointer,
              inputLength
            );
            inputPointer += inputLength + 3;
            outputPointer += inputLength;
          } else {
            inputPointer += 3;
          }
          memcpy(
            outputPointer,
            argValuePointer,
            argValueLength
          );
          outputLength += inputLength + argValueLength;
          outputPointer += argValueLength;
          ix += 3;
          lix = ix;
          hits ++;
        } else {
          ix ++;
        }
      }
      ix = input.length;    
    }
    if (outputLength > 0) {
      if (ix > lix ) {
        memcpy(
          outputPointer,
          inputPointer,
          ix - lix
        );
        outputLength += (ix - lix);
      }
      assembly {
        // set final output length
        mstore(output, outputLength)
        // protect output bytes
        mstore(0x40, add(mload(0x40), add(outputLength, 32)))
      }
    }
    else {
      return (input, 0);
    }
  }

  /// @notice Replace indexed string wildcards by correspondent substrings.
  /// @dev Wildcard format: "\#\", with # in ["0".."9"].
  /// @param input String potentially containing wildcards.
  /// @param args Array of substring values for replacing indexed wildcards.
  /// @return output Resulting string after replacing all wildcards.
  function replace(string memory input, string[] memory args)
    internal pure
    returns (string memory)
  {
    (bytes memory _outputBytes, ) = replace(bytes(input), args);
    return string(_outputBytes);
  }

  /// @notice Replace last indexed wildcard by given substring.
  /// @dev Wildcard format: "\#\", with # in ["0".."9"].
  /// @param input String potentially containing wildcards.
  /// @param argIndex Index of the wildcard to be replaced.
  /// @param argValue Replacing string to be used.
  /// @return output Resulting string after replacing all wildcards.
  function replace(string memory input, uint8 argIndex, string memory argValue)
    internal pure
    returns (string memory)
  {
    (bytes memory _outputBytes, ) = replace(bytes(input), argIndex, argValue);
    return string(_outputBytes);
  }

  /// @notice Move the inner cursor of the buffer to a relative or absolute position.
  /// @param buffer An instance of `Buffer`.
  /// @param offset How many bytes to move the cursor forward.
  /// @param relative Whether to count `offset` from the last position of the cursor (`true`) or the beginning of the
  /// buffer (`true`).
  /// @return The final position of the cursor (will equal `offset` if `relative` is `false`).
  // solium-disable-next-line security/no-assign-params
  function seek(
      Buffer memory buffer,
      uint offset,
      bool relative
    )
    internal pure
    withinRange(offset, buffer.data.length)
    returns (uint)
  {
    // Deal with relative offsets
    if (relative) {
      offset += buffer.cursor;
    }
    buffer.cursor = offset;
    return offset;
  }

  /// @notice Move the inner cursor a number of bytes forward.
  /// @dev This is a simple wrapper around the relative offset case of `seek()`.
  /// @param buffer An instance of `Buffer`.
  /// @param relativeOffset How many bytes to move the cursor forward.
  /// @return The final position of the cursor.
  function seek(
      Buffer memory buffer,
      uint relativeOffset
    )
    internal pure
    returns (uint)
  {
    return seek(
      buffer,
      relativeOffset,
      true
    );
  }

  /// @notice Copy bytes from one memory address into another.
  /// @dev This function was borrowed from Nick Johnson's `solidity-stringutils` lib, and reproduced here under the terms
  /// of [Apache License 2.0](https://github.com/Arachnid/solidity-stringutils/blob/master/LICENSE).
  /// @param dest Address of the destination memory.
  /// @param src Address to the source memory.
  /// @param len How many bytes to copy.
  // solium-disable-next-line security/no-assign-params
  function memcpy(
      uint dest,
      uint src,
      uint len
    )
    private pure
  {
    unchecked {
      // Copy word-length chunks while possible
      for (; len >= 32; len -= 32) {
        assembly {
          mstore(dest, mload(src))
        }
        dest += 32;
        src += 32;
      }
      if (len > 0) {
        // Copy remaining bytes
        uint _mask = 256 ** (32 - len) - 1;
        assembly {
          let srcpart := and(mload(src), not(_mask))
          let destpart := and(mload(dest), _mask)
          mstore(dest, or(destpart, srcpart))
        }
      }
    }
  }

}