pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/CBOR.sol";

contract TestCBOR {
    using CBOR for CBOR.Value;

    event Log(string _topic, uint256 _value);
    event Log(string _topic, bytes _value);

    function testUint64DecodeDiscriminant() public {
        CBOR.Value memory decoded = CBOR.valueFromBytes(hex"1b0020000000000000");
        Assert.equal(uint(decoded.majorType), 0, "CBOR-encoded Uint64 value should be decoded into a CBOR.Value with major type 0");
    }
    function testUint64DecodeValue() public {
        uint64 decoded = CBOR.valueFromBytes(hex"1b0020000000000000").decodeUint64();
        Assert.equal(uint(decoded), 9007199254740992, "CBOR-encoded Uint64 value should be decoded into a CBOR.Value containing the correct Uint64 value");
    }

    function testInt128DecodeDiscriminant() public {
        CBOR.Value memory decoded = CBOR.valueFromBytes(hex"3bfffffffffffffffe");
        Assert.equal(uint(decoded.majorType), 1, "CBOR-encoded Int128 value should be decoded into a CBOR.Value with major type 1");
    }
    function testInt128DecodeValue() public {
        int128 decoded = CBOR.valueFromBytes(hex"3bfffffffffffffffe").decodeInt128();
        Assert.equal(int(decoded), -18446744073709551615, "CBOR-encoded Int128 value should be decoded into a CBOR.Value containing the correct Uint64 value");
    }

    function testBytes0DecodeDiscriminant() public {
        CBOR.Value memory decoded = CBOR.valueFromBytes(hex"40");
        Assert.equal(uint(decoded.majorType), 2, "Empty CBOR-encoded Bytes value should be decoded into a CBOR.Value with major type 2");
    }
    function testBytes0DecodeValue() public {
        bytes memory encoded = hex"40";
        bytes memory decoded = CBOR.valueFromBytes(encoded).decodeBytes();
        Assert.equal(decoded.length, 0, "Empty CBOR-encoded Bytes value should be decoded into an empty CBOR.Value.Bytes");
    }

    function testBytes4BDecodeDiscriminant() public {
        CBOR.Value memory decoded = CBOR.valueFromBytes(hex"4401020304");
        Assert.equal(uint(decoded.majorType), 2, "CBOR-encoded Bytes value should be decoded into a CBOR.Value with major type 2");
    }
    function testBytes4DecodeValue() public {
        bytes memory encoded = hex"4401020304";
        bytes memory decoded = CBOR.valueFromBytes(encoded).decodeBytes();
        bytes memory expected = abi.encodePacked(uint8(1), uint8(2), uint8(3), uint8(4));
        Assert.isTrue(decoded[0] == expected[0] && decoded[1] == decoded[1] && decoded[2] == expected[2] && decoded[3] == decoded[3], "CBOR-encoded Bytes value should be decoded into a CBOR.Value.Bytes containing the correct Bytes value");
    }

    function testStringDecodeDiscriminant() public {
        CBOR.Value memory decoded = CBOR.valueFromBytes(hex"6449455446");
        Assert.equal(uint(decoded.majorType), 3, "CBOR-encoded String value should be decoded into a CBOR.Value with major type 3");
    }
    function testStringDecodeValue() public {
        bytes memory encoded = hex"6449455446";
        string memory decoded = CBOR.valueFromBytes(encoded).decodeString();
        string memory expected = "IETF";

        Assert.equal(decoded, expected, "CBOR-encoded String value should be decoded into a CBOR.Value.String containing the correct String value");
    }

    function testFloatDecodeDiscriminant() public {
        CBOR.Value memory decoded = CBOR.valueFromBytes(hex"f90001");
        Assert.equal(uint(decoded.majorType), 7, "CBOR-encoded Float value should be decoded into a CBOR.Value with major type 7");
    }
    function testFloatDecodeSmallestSubnormal() public {
        bytes memory encoded = hex"f90001";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeLargestSubnormal() public {
        bytes memory encoded = hex"f903ff";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeSmallestPositiveNormal() public {
        bytes memory encoded = hex"f90400";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeLargestNormal() public {
        bytes memory encoded = hex"f97bff";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 655040000;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeLargestLessThanOne() public {
        bytes memory encoded = hex"f93bff";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 9995;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeOne() public {
        bytes memory encoded = hex"f93c00";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 10000;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeSmallestGreaterThanOne() public {
        bytes memory encoded = hex"f93c01";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 10009;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeOneThird() public {
        bytes memory encoded = hex"f93555";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 3332;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeMinusTwo() public {
        bytes memory encoded = hex"f9c000";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = -20000;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeZero() public {
        bytes memory encoded = hex"f90000";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
    function testFloatDecodeMinusZero() public {
        bytes memory encoded = hex"f98000";
        int32 decoded = CBOR.valueFromBytes(encoded).decodeFixed16();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBOR.Value.Float containing the correct Float value");
    }
}
