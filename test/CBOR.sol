pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "../contracts/CBOR.sol";

contract TestCBOR {

    event Log(string _topic, uint256 _value);
    event Log(string _topic, bytes _value);

    function testUint64DecodeDiscriminant() public {
        CBORValue decoded = CBOR.decode(hex"1b0020000000000000");
        Assert.equal(uint(decoded.getType()), 2, "CBOR-encoded Uint64 value should be decoded into a CBORValue of type Integer");
    }
    function testUint64DecodeValue() public {
        uint64 decoded = CBOR.decode(hex"1b0020000000000000").asUint64();
        Assert.equal(uint(decoded), 9007199254740992, "CBOR-encoded Uint64 value should be decoded into a CBORValue containing the correct Uint64 value");
    }

    function testInt128DecodeDiscriminant() public {
        CBORValue decoded = CBOR.decode(hex"3bfffffffffffffffe");
        Assert.equal(uint(decoded.getType()), 2, "CBOR-encoded Int128 value should be decoded into a CBORValue of type Integer");
    }
    function testInt128DecodeValue() public {
        int128 decoded = CBOR.decode(hex"3bfffffffffffffffe").asInt128();
        Assert.equal(int(decoded), -18446744073709551615, "CBOR-encoded Int128 value should be decoded into a CBORValue containing the correct Uint64 value");
    }

    function testBytes0DecodeDiscriminant() public {
        CBORValue decoded = CBOR.decode(hex"40");
        Assert.equal(uint(decoded.getType()), 4, "Empty CBOR-encoded Bytes value should be decoded into a CBORValue of type Bytes");
    }
    function testBytes0DecodeValue() public {
        bytes memory encoded = hex"40";
        bytes memory decoded = CBOR.decode(encoded).asBytes();
        Assert.equal(decoded.length, 0, "Empty CBOR-encoded Bytes value should be decoded into an empty CBORValue.Bytes");
    }

    function testBytes4BDecodeDiscriminant() public {
        CBORValue decoded = CBOR.decode(hex"4401020304");
        Assert.equal(uint(decoded.getType()), 4, "CBOR-encoded Bytes value should be decoded into a CBORValue of type Bytes");
    }
    function testBytes4DecodeValue() public {
        bytes memory encoded = hex"4401020304";
        bytes memory decoded = CBOR.decode(encoded).asBytes();
        bytes memory expected = abi.encodePacked(uint8(1), uint8(2), uint8(3), uint8(4));
        Assert.isTrue(decoded[0] == expected[0] && decoded[1] == decoded[1] && decoded[2] == expected[2] && decoded[3] == decoded[3], "CBOR-encoded Bytes value should be decoded into a CBORValue.Bytes containing the correct Bytes value");
    }

    function testStringDecodeDiscriminant() public {
        CBORValue decoded = CBOR.decode(hex"6449455446");
        Assert.equal(uint(decoded.getType()), 5, "CBOR-encoded String value should be decoded into a CBORValue of type String");
    }
    function testStringDecodeValue() public {
        bytes memory encoded = hex"6449455446";
        string memory decoded = CBOR.decode(encoded).asString();
        string memory expected = "IETF";

        Assert.equal(decoded, expected, "CBOR-encoded String value should be decoded into a CBORValue.String containing the correct String value");
    }

    function testFloatDecodeDiscriminant() public {
        CBORValue decoded = CBOR.decode(hex"f90001");
        Assert.equal(uint(decoded.getType()), 3, "CBOR-encoded Float value should be decoded into a CBORValue of type Float");
    }
    function testFloatDecodeSmallestSubnormal() public {
        bytes memory encoded = hex"f90001";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeLargestSubnormal() public {
        bytes memory encoded = hex"f903ff";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeSmallestPositiveNormal() public {
        bytes memory encoded = hex"f90400";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeLargestNormal() public {
        bytes memory encoded = hex"f97bff";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 655040000;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeLargestLessThanOne() public {
        bytes memory encoded = hex"f93bff";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 9995;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeOne() public {
        bytes memory encoded = hex"f93c00";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 10000;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeSmallestGreaterThanOne() public {
        bytes memory encoded = hex"f93c01";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 10009;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeOneThird() public {
        bytes memory encoded = hex"f93555";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 3332;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeMinusTwo() public {
        bytes memory encoded = hex"f9c000";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = -20000;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeZero() public {
        bytes memory encoded = hex"f90000";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
    function testFloatDecodeMinusZero() public {
        bytes memory encoded = hex"f98000";
        int32 decoded = CBOR.decode(encoded).asFixed();
        int32 expected = 0;

        Assert.equal(decoded, expected, "CBOR-encoded Float value should be decoded into a CBORValue.Float containing the correct Float value");
    }
}
