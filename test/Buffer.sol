pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "../contracts/Buffer.sol";

contract TestBuffer {

    using Buffer for Buffer.buffer;

    event Log(string _topic, uint256 _value);

    function testReadUint8() public {
        uint8 expected = 31;
        bytes memory data = abi.encodePacked(expected);
        Buffer.buffer memory buf = Buffer.buffer(data, 0);
        uint8 actual = buf.readUint8();

        Assert.equal(uint(actual), uint(expected), "Read Uint8 from a Buffer");
    }

    function testReadUint16() public {
        uint16 expected = 31415;
        bytes memory data = abi.encodePacked(expected);
        Buffer.buffer memory buf = Buffer.buffer(data, 0);

        uint16 actual = buf.readUint16();
        Assert.equal(uint(actual), uint(expected), "Read Uint16 from a Buffer");
    }

    function testReadUint32() public {
        uint32 expected = 3141592653;
        bytes memory data = abi.encodePacked(expected);
        Buffer.buffer memory buf = Buffer.buffer(data, 0);

        uint32 actual = buf.readUint32();
        Assert.equal(uint(actual), uint(expected), "Read Uint32 from a Buffer");
    }

    function testReadUint64() public {
        uint64 expected = 3141592653589793238;
        bytes memory data = abi.encodePacked(expected);
        Buffer.buffer memory buf = Buffer.buffer(data, 0);

        uint64 actual = buf.readUint64();
        Assert.equal(uint(actual), uint(expected), "Read Uint64 from a Buffer");
    }

    function testMultipleReadHead() public {
        uint8 small = 31;
        uint64 big = 3141592653589793238;
        bytes memory data = abi.encodePacked(small, big);
        Buffer.buffer memory buf = Buffer.buffer(data, 0);

        buf.readUint8();
        uint64 actualBig = buf.readUint64();
        Assert.equal(uint(actualBig), uint(big), "Read multiple data chunks from the same Buffer (inner cursor works as expected)");
    }


}
