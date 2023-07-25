// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/libs/WitnetBuffer.sol";

contract TestWitnetBuffer {

  using WitnetBuffer for WitnetBuffer.Buffer;

  event Log(string _topic, uint256 _value);

  function testArgsCountsOf() external {
    Assert.equal(WitnetBuffer.argsCountOf(bytes("aaaaaa\\0\\")), 1, "bad count if trailing wildcard");
    Assert.equal(WitnetBuffer.argsCountOf(bytes("\\9\\aaaaaaa\\1\\")), 10, "bad count if disordered wildcard indexes");
    Assert.equal(WitnetBuffer.argsCountOf(bytes("\\6\\\\6\\\\6\\")), 7, "bad count if repeated wildcard indexes");
  }

  function testFork() external {
    WitnetBuffer.Buffer memory buff = WitnetBuffer.Buffer(
      hex"00000000000000000000000000000000000000000000635C305C0102030405060708090a",
      0
    );
    WitnetBuffer.Buffer memory fork = buff.fork();
    buff.data[0] = 0xff;
    fork.next();
    Assert.notEqual(
      buff.cursor,
      fork.cursor,
      "not forked :/"
    );
    Assert.equal(
      uint(uint8(buff.data[0])),
      uint(uint8(fork.data[0])),
      "bad fork :/"
    );    
  }

  function testMutate() external {
    WitnetBuffer.Buffer memory buff = WitnetBuffer.Buffer(
      hex"00000000000000000000000000000000000000000000635C305C0102030405060708090a",
      23
    );
    emit Log(string(buff.data), buff.data.length);
    buff.mutate(3, bytes("token1Price"));
    emit Log(string(buff.data), buff.data.length);
    Assert.equal(
      keccak256(buff.data),
      keccak256(hex"0000000000000000000000000000000000000000000063746F6B656E3150726963650102030405060708090a"),
      "Wildcards replacement not good :/"
    );
  }

  function testConcatShortStrings() external {
    bytes[] memory strs = new bytes[](4);
    strs[0] = bytes("Hello ");
    strs[1] = bytes("decentralized ");
    strs[2] = bytes("world");
    strs[3] = bytes("!");
    bytes memory phrase = WitnetBuffer.concat(strs);
    emit Log(string(phrase), phrase.length);
    Assert.equal(
      keccak256(phrase),
      keccak256(bytes("Hello decentralized world!")),
      "Concat of strings not good :/"
    );
  }

  function testConcatLongStrings() external {
    bytes[] memory strs = new bytes[](4);
    strs[0] = bytes("0123456789012345678901234567890123456789012345678901234567890123");
    strs[1] = bytes("01234567890123456789012345678901234567890123456789012345678901234");
    strs[2] = bytes("012345678901234567890123456789012345678901234567890123456789012345");
    strs[3] = bytes("0123456789012345678901234567890123456789012345678901234567890123456");
    bytes memory phrase = WitnetBuffer.concat(strs);
    emit Log(string(phrase), phrase.length);
    Assert.equal(
      keccak256(phrase),
      keccak256(bytes("0123456789012345678901234567890123456789012345678901234567890123012345678901234567890123456789012345678901234567890123456789012340123456789012345678901234567890123456789012345678901234567890123450123456789012345678901234567890123456789012345678901234567890123456")),
      "Concat of strings not good :/"
    );
  }

  function testReplace() external {
    string memory input = "\\0\\/image/\\1\\?digest=sha-256";
    string[] memory args = new string[](2);
    args[0] = "https://api.whatever.com/";
    args[1] = "1";
    string memory phrase = WitnetBuffer.replace(input, args);
    emit Log(phrase, bytes(phrase).length);
    Assert.equal(
      keccak256(bytes(phrase)),
      keccak256(bytes("https://api.whatever.com//image/1?digest=sha-256")),
      "String replacement not good :/"
    );
  }

  function testReplace0Args() external {
    string memory input = "In a village of La Mancha, the name of which I have no desire to call to mind, there lived not long since one of those gentlemen that keep a lance in the lance-rack, an old buckler, a lean hack, and a greyhound for coursing";
    string[] memory args = new string[](1);
    args[0] = "Don Quixote";
    string memory phrase = WitnetBuffer.replace(input, args);
    emit Log(phrase, bytes(phrase).length);
    Assert.equal(
      keccak256(bytes(phrase)),
      keccak256(bytes(input)),
      "String replacement not good :/"
    );
  }

  function testReplace1Args() external {
    string memory input = "\\0\\";
    string[] memory args = new string[](1);
    args[0] = "Hello!";
    string memory phrase = WitnetBuffer.replace(input, args);
    emit Log(phrase, bytes(phrase).length);
    Assert.equal(
      keccak256(bytes(phrase)),
      keccak256(bytes("Hello!")),
      "String replacement not good :/"
    );
  }

  function testReplace4Args() external {
    string memory input = "Test: \\0\\ \\1\\ \\2\\!";
    string[] memory args = new string[](3);
    args[0] = "Hello";
    args[1] = "decentralized";
    args[2] = "world";
    string memory phrase = WitnetBuffer.replace(input, args);
    emit Log(phrase, bytes(phrase).length);
    Assert.equal(
      keccak256(bytes(phrase)),
      keccak256(bytes("Test: Hello decentralized world!")),
      "String replacement not good :/"
    );
  }

  function testReplace4ArgsUnordered() external {
    string memory input = "Test: \\2\\ \\0\\ \\3\\!";
    string[] memory args = new string[](4);
    args[2] = "Hello";
    args[0] = "decentralized";
    args[3] = "world";
    string memory phrase = WitnetBuffer.replace(input, args);
    emit Log(phrase, bytes(phrase).length);
    Assert.equal(
      keccak256(bytes(phrase)),
      keccak256(bytes("Test: Hello decentralized world!")),
      "String replacement not good :/"
    );
  }

  function testRead31bytes() external {
    bytes memory data = hex"58207eadcf3ba9a9a860b4421ee18caa6dca4738fef266aa7b3668a2ff97304cfcab";
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 1);
    bytes memory actual = buf.read(31);
    
    Assert.equal(31, actual.length, "Read 31 bytes from a Buffer");
  }

  function testRead32bytes() external {
    bytes memory data = hex"58207eadcf3ba9a9a860b4421ee18caa6dca4738fef266aa7b3668a2ff97304cfcab";
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 1);
    bytes memory actual = buf.read(32);
    
    Assert.equal(32, actual.length, "Read 32 bytes from a Buffer");
  }

  function testRead33bytes() external {
    bytes memory data = hex"58207eadcf3ba9a9a860b4421ee18caa6dca4738fef266aa7b3668a2ff97304cfcabff";
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 1);
    bytes memory actual = buf.read(33);
    
    Assert.equal(33, actual.length, "Read 33 bytes from a Buffer");
  }

  function testReadUint8() external {
    uint8 expected = 31;
    bytes memory data = abi.encodePacked(expected);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);
    uint8 actual = buf.readUint8();

    Assert.equal(uint(actual), uint(expected), "Read Uint8 from a Buffer");
  }

  function testReadUint16() external {
    uint16 expected = 31415;
    bytes memory data = abi.encodePacked(expected);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);

    uint16 actual = buf.readUint16();
    Assert.equal(uint(actual), uint(expected), "Read Uint16 from a Buffer");
  }

  function testReadUint32() external {
    uint32 expected = 3141592653;
    bytes memory data = abi.encodePacked(expected);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);

    uint32 actual = buf.readUint32();
    Assert.equal(uint(actual), uint(expected), "Read Uint32 from a Buffer");
  }

  function testReadUint64() external {
    uint64 expected = 3141592653589793238;
    bytes memory data = abi.encodePacked(expected);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);

    uint64 actual = buf.readUint64();
    Assert.equal(uint(actual), uint(expected), "Read Uint64 from a Buffer");
  }

  function testReadUint128() external {
    uint128 expected = 314159265358979323846264338327950288419;
    bytes memory data = abi.encodePacked(expected);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);

    uint128 actual = buf.readUint128();
    Assert.equal(uint(actual), uint(expected), "Read Uint128 from a Buffer");
  }

  function testReadUint256() external {
    uint256 expected = 31415926535897932384626433832795028841971693993751058209749445923078164062862;
    bytes memory data = abi.encodePacked(expected);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);

    uint256 actual = buf.readUint256();
    Assert.equal(uint(actual), uint(expected), "Read Uint64 from a Buffer");
  }

  function testReadFloat64() external {
    WitnetBuffer.Buffer memory buf;
    buf = WitnetBuffer.Buffer(hex"3FE051EB851EB852", 0);
    Assert.equal(
      buf.readFloat64(),
      510000000000000,
      "Reading Float64(0.51)"
    );
    buf = WitnetBuffer.Buffer(hex"3FE5555555555555", 0);
    Assert.equal(
      buf.readFloat64(),
      666666666666666,
      "Reading Float64(2/3)"
    );
    buf = WitnetBuffer.Buffer(hex"400921FB54442D18", 0);
    Assert.equal(
      buf.readFloat64(),
      3141592653589793,
      "Reading Float64(pi)"
    );
  }

  function testMultipleReadHead() external {
    uint8 small = 31;
    uint64 big = 3141592653589793238;
    bytes memory data = abi.encodePacked(small, big);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);

    buf.readUint8();
    uint64 actualBig = buf.readUint64();
    Assert.equal(uint(actualBig), uint(big), "Read multiple data chunks from the same Buffer (inner cursor works as expected)");
  }

  function testReadUint8asUint16() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    uint8 input = 0xAA;
    bytes memory data = abi.encodePacked(input);

    TestWitnetBuffer(address(throwProxy)).errorReadAsUint16(data);
    (r, error) = throwProxy.execute{gas: 100000}();
    Assert.isFalse(r, "Reading uint8 as uint16 should fail");
  }

  function testReadUint16asUint32() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    uint16 input = 0xAAAA;
    bytes memory data = abi.encodePacked(input);

    TestWitnetBuffer(address(throwProxy)).errorReadAsUint32(data);
    (r, error) = throwProxy.execute{gas: 100000}();
    Assert.isFalse(r, "Reading uint16 as uint32 should fail");
  }

  function testReadUint32asUint64() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    uint32 input = 0xAAAAAAAA;
    bytes memory data = abi.encodePacked(input);

    TestWitnetBuffer(address(throwProxy)).errorReadAsUint64(data);
    (r, error) = throwProxy.execute{gas: 100000}();
    Assert.isFalse(r, "Reading uint32 as uint64 should fail");
  }

  function testReadUint64asUint128() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    uint64 input = 0xAAAAAAAAAAAAAAAA;
    bytes memory data = abi.encodePacked(input);

    TestWitnetBuffer(address(throwProxy)).errorReadAsUint128(data);
    (r, error) = throwProxy.execute{gas: 100000}();
    Assert.isFalse(r, "Reading uint64 as uint128 should fail");
  }

  function testReadUint128asUint256() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    uint128 input = 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
    bytes memory data = abi.encodePacked(input);

    TestWitnetBuffer(address(throwProxy)).errorReadAsUint256(data);
    (r, error) = throwProxy.execute{gas: 100000}();
    Assert.isFalse(r, "Reading uint128 as uint256 should fail");
  }

  function testNextOutOfBounds() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    uint8 input = 0xAA;
    bytes memory data = abi.encodePacked(input);
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);
    buf.next();

    TestWitnetBuffer(address(throwProxy)).errorReadNext(buf);
    (r, error) = throwProxy.execute{gas: 100000}();
    Assert.isFalse(r, "Next for out of bounds fail");
  }

  function errorReadAsUint16(bytes memory data) public {
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);
    buf.readUint16();
  }

  function errorReadAsUint32(bytes memory data) public {
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);
    buf.readUint32();
  }

  function errorReadAsUint64(bytes memory data) public {
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);
    buf.readUint64();
  }

  function errorReadAsUint128(bytes memory data) public {
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);
    buf.readUint128();
  }

  function errorReadAsUint256(bytes memory data) public {
    WitnetBuffer.Buffer memory buf = WitnetBuffer.Buffer(data, 0);
    buf.readUint256();
  }

  function errorReadNext(WitnetBuffer.Buffer memory buf) public {
    buf.next();
  }

}

// Proxy contract for testing throws
contract ThrowProxy {
  address public target;
  bytes internal data;

  constructor (address _target) {
    target = _target;
  }

  // solhint-disable payable-fallback
  fallback () external {    
    data = msg.data;
  }


  function execute() public returns (bool, bytes memory) {
    // solhint-disable-next-line
    return target.call(data);
  }
}
