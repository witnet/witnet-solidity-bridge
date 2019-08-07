pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "./Buffer.sol";

/**
 * @title A decoder library for Concise Binary Object Representation (CBOR) data format (RFC7049), implemented in pure
 * Solidity.
 * @dev The algorithms found here are partially based on [cbor-js](https://github.com/paroga/cbor-js) and the RFC7049
 * itself.
 * @notice Contract writers can make use of this library to decode CBOR bytes into an instance of the CBORValue.
 * contract, which provides convenient methods for reading the values as native Solidity types.
 */
library CBOR {
    enum CBORTypes { Integer, NegativeInteger, Bytes, Text, Array, Map, Tag, NoContent }
    using Buffer for Buffer.buffer;

    // Constants for
    int64 constant INT64_MAX = ~int64(0);
    uint64 constant UINT64_MAX = ~uint64(0);

    /**
     * @dev Decode a CBORValue from a byte array.
     * @param _input A byte array containing a well-formed RFC7049 serialized value.
     * @return Requests-only merkle root hash in the block header.
     */
    function decode(bytes memory _input) internal returns(CBORValue) {
        Buffer.buffer memory buffer = Buffer.buffer(_input, 0);
        CBORValue cbor = new CBORValue();

        uint8 initialByte;
        uint8 majorType;
        uint8 additionalInformation;
        uint64 length;

        bool isTagged = true;
        while (isTagged) {
            // Extract basic CBOR properties from input bytes
            initialByte = buffer.readUint8();
            majorType = initialByte >> 5;
            additionalInformation = initialByte & 0x1f;

            // Item length calculation and validation
            length = readLength(buffer, additionalInformation);
            require(length < UINT64_MAX || (majorType > 1 && majorType < 7), "Invalid length of serialized input");

            // Early CBOR tag parsing.
            // This does not interrupt the decoding, it only intercepts the tag and restarts the
            if (majorType == 6) {
                cbor.setTag(length);
            } else {
                isTagged = false;
            }
        }

        // Early float parsing.
        // This returns early, but all other `NoContent` values and the rest of major types need additional processing.
        if (majorType == 7) {
            if (additionalInformation == 25) {
                cbor.setFixed(buffer.readFloat16());
                return cbor;
            }
            // TODO: support Float32
            //else if (additionalInformation == 26) {
            //    return readFloat32();
            // TODO: support Float64
            //} else if (additionalInformation == 27) {
            //    return readFloat64();
            //}
        }

        // Specific parsers for each CBOR major type
        // Major type 0: natural numbers
        if (majorType == 0) {
            cbor.setUint64(length);
        // Major type 1: negative integer numbers
        } else if (majorType == 1) {
            cbor.setInt128(int128(-1) - int128(length));
        // Major type 2: raw bytes
        } else if (majorType == 2) {
            if (length == UINT64_MAX) {
                bytes memory bytesData;
                bool done;
                uint8 limit = 0;
                while(!done && limit < 2) {
                    uint64 itemLength = readIndefiniteStringLength(buffer, majorType);
                    if (itemLength >= 0) {
                        bytesData = abi.encodePacked(bytesData, buffer.read(itemLength));
                    } else {
                        done = true;
                    }
                    limit++;
                }
                cbor.setBytes(bytesData);
            } else {
                cbor.setBytes(buffer.read(length));
            }
        // Major type 3: text
        } else if (majorType == 3) {
            if (length == UINT64_MAX) {
                bytes memory textData;
                bool done;
                while(!done) {
                    uint64 itemLength = readIndefiniteStringLength(buffer, majorType);
                    if (itemLength >= 0) {
                        textData = abi.encodePacked(textData, readText(buffer, itemLength / 4));
                    } else {
                        done = true;
                    }
                }
                cbor.setString(string(textData));
            } else {
                cbor.setString(string(readText(buffer, length)));
            }
        // Major type 4: arrays
        } else if (majorType == 4) {
            // TODO: add support for Array
        // Major type 5: maps
        } else if (majorType == 5) {
            // TODO: add support for Map
        // Major type 7: "NoContent" values
        } else if (majorType == 7) {
            // TODO: add support for NoContent
        }

        return cbor;
    }

    // Reads the length of the next CBOR item from a buffer, consuming a different number of bytes depending on the
    // value of the `additionalInformation` argument.
    function readLength(Buffer.buffer memory _buffer, uint8 additionalInformation) private pure returns(uint64) {
        if (additionalInformation < 24) {
            return additionalInformation;
        }
        if (additionalInformation == 24) {
            return _buffer.readUint8();
        }
        if (additionalInformation == 25) {
            return _buffer.readUint16();
        }
        if (additionalInformation == 26) {
            return _buffer.readUint32();
        }
        if (additionalInformation == 27) {
            return _buffer.readUint64();
        }
        if (additionalInformation == 31) {
            return UINT64_MAX;
        }
        revert("Invalid length encoding (additionalInformation > 31)");
    }

    // Read the length of a CBOR indifinite-length item (arrays, maps, byte strings and text) from a buffer, consuming
    // as many bytes as specified by the first byte.
    function readIndefiniteStringLength(Buffer.buffer memory _buffer, uint8 majorType) private pure returns(uint64)  {
        uint8 initialByte = _buffer.readUint8();
        if (initialByte == 0xff) {
            return UINT64_MAX;
        }
        uint64 length = readLength(_buffer, initialByte & 0x1f);
        require(length < UINT64_MAX && (initialByte >> 5) == majorType, "Invalid indefinite length");
        return length;
    }

    // Read a text string of a given length from a buffer. Returns a `bytes memory` value for the sake of genericness,
    // but it can be easily casted into a string with `string(result)`.
    function readText(Buffer.buffer memory _buffer, uint64 _length) private pure returns(bytes memory) {
        bytes memory result;
        for (uint64 index = 0; index < _length; index++) {
            uint8 value = _buffer.readUint8();
            if (value & 0x80 != 0) {
                if (value < 0xe0) {
                    value = (value & 0x1f) <<  6
                    | (_buffer.readUint8() & 0x3f);
                    _length -= 1;
                } else if (value < 0xf0) {
                    value = (value & 0x0f) << 12
                    | (_buffer.readUint8() & 0x3f) << 6
                    | (_buffer.readUint8() & 0x3f);
                    _length -= 2;
                } else {
                    value = (value & 0x0f) << 18
                    | (_buffer.readUint8() & 0x3f) << 12
                    | (_buffer.readUint8() & 0x3f) << 6
                    | (_buffer.readUint8() & 0x3f);
                    _length -= 3;
                }
            }
            result = abi.encodePacked(result, value);
        }
        return result;
    }

}

/**
 * @title Encapsulates the different data types supported by CBOR and provides convenient getters and setters for each.
 * @notice This is specially useful when paired with the CBOR decoder library, which uses instances of this contract as
 * the output type of its `decode` function.
 */
contract CBORValue {

    // Check if the contract has been set to one specific type
    modifier instanceOf (CBORTypes _type) {
        require(discriminant == _type);
        _;
    }

    // Enumeration of all the supported intermediate types.
    // Intermediate types are a user-friendly abstraction that sits half-way between
    enum CBORTypes { Null, Bool, Integer, Fixed, Bytes, Text, Array, Map }

    // Generic wrapper for an error
    struct Error {
        uint16 code;
        bytes extra;
    }

    CBORTypes discriminant = CBORTypes.Null;
    uint64 tag = ~uint64(0); // UINT64_MAX
    bool isTagged = false;

    bytes bytesValue;
    Error errorValue;
    int32 int32Value;
    int128 int128Value;
    uint64 uint64Value;
    string stringValue;

    /**
     * @notice Make this contract contain a raw bytes value.
     * @param _value The `bytes` value to wrap into this contract.
     */
    function setBytes(bytes memory _value) public {
        discriminant = CBORTypes.Bytes;
        bytesValue = _value;
    }

    /**
     * @notice Make this contract contain a fixed-point decimal numeric value.
     * @param _value The `int32` value to wrap into this contract.
     */
    function setFixed(int32 _value) public {
        discriminant = CBORTypes.Fixed;
        int32Value = _value;
    }

    /**
     * @notice Make this contract contain an integer numeric value.
     * @param _value The `int128` value to wrap into this contract.
     */
    function setInt128(int128 _value) public {
        discriminant = CBORTypes.Integer;
        int128Value = _value;
    }

    /**
     * @notice Make this contract contain a text string value.
     * @param _value The `string` value to wrap into this contract.
     */
    function setString(string memory _value) public {
        discriminant = CBORTypes.Text;
        stringValue = _value;
    }

    /**
     * @notice Tag the value of this contract.
     * @param _tag The `uint64` value to use as CBOR tag.
     */
    function setTag(uint64 _tag) public {
        tag = _tag;
    }

    /**
     * @notice Make this contract contain a natural numeric value.
     * @param _value The `uint64` value to wrap into this contract.
     */
    function setUint64(uint64 _value) public {
        discriminant = CBORTypes.Integer;
        uint64Value = _value;
    }

    /**
     * @notice Get the raw bytes value of this contract as a `bytes memory` value
     * @return The `bytes memory` contained in this contract.
     */
    function asBytes () public view instanceOf(CBORTypes.Bytes) returns(bytes memory) {
        return bytesValue;
    }

    /**
     * @notice Get the error value of this contract as a `CBORValue.Error memory` value
     * @return The `CBORValue.Error memory` contained in this contract.
     */
    function asError () public view instanceOf(CBORTypes.Bytes) returns(Error memory) {
        return errorValue;
    }

    /**
     * @notice Get the fixed-point decimal numeric value of this contract as an `int32` value
     * @return The `int32` contained in this contract.
     */
    function asFixed () public view instanceOf(CBORTypes.Fixed) returns(int32) {
        return int32Value;
    }

    /**
     * @notice Get the integer numeric value of this contract as an `int128` value
     * @return The `int128` contained in this contract.
     */
    function asInt128 () public view instanceOf(CBORTypes.Integer) returns(int128) {
        return int128Value;
    }

    /**
     * @notice Get the text string value of this contract as a `string memory` value
     * @return The `string memory` contained in this contract.
     */
    function asString () public view instanceOf(CBORTypes.Text) returns(string memory) {
        return stringValue;
    }

    /**
     * @notice Get the natural numeric value of this contract as a `uint64` value
     * @return The `uint64` contained in this contract.
     */
    function asUint64 () public view instanceOf(CBORTypes.Integer) returns(uint64) {
        return uint64Value;
    }

    /**
     * @notice Get any CBOR tag that may be associated to this contract
     * @return The currently set CBOR tag (UINT64_MAX by default)
     */
    function getTag () public view returns(uint64) {
        return tag;
    }

    /**
     * @notice Tell which kind of value is stored in this contract
     * @return One of the member of the CBORTypes enums
     */
    function getType () public view returns(CBORTypes) {
        return discriminant;
    }

}
