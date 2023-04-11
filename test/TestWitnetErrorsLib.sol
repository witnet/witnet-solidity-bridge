// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/libs/WitnetErrorsLib.sol";

contract TestWitnetErrorsLib {

  using Witnet for Witnet.Result;

  event Log(bytes data, uint256 length);

  // Test decoding of `RadonError` error codes
  function testErrorCodes1() external {
    (Witnet.ResultErrorCodes errorCodeEmpty,) = WitnetErrorsLib.parseResultError(hex"D82780");
    (Witnet.ResultErrorCodes errorCode0x00,) = WitnetErrorsLib.parseResultError(hex"D8278100");
    (Witnet.ResultErrorCodes errorCode0x01,) = WitnetErrorsLib.parseResultError(hex"D8278101");
    (Witnet.ResultErrorCodes errorCode0x02,) = WitnetErrorsLib.parseResultError(hex"D8278102");
    (Witnet.ResultErrorCodes errorCode0x03,) = WitnetErrorsLib.parseResultError(hex"D8278103");
    (Witnet.ResultErrorCodes errorCode0x10,) = WitnetErrorsLib.parseResultError(hex"D8278110");
    (Witnet.ResultErrorCodes errorCode0x11,) = WitnetErrorsLib.parseResultError(hex"D8278111");
    (Witnet.ResultErrorCodes errorCode0x20,) = WitnetErrorsLib.parseResultError(hex"D827811820");
    (Witnet.ResultErrorCodes errorCode0x30,) = WitnetErrorsLib.parseResultError(hex"D827811830");
    (Witnet.ResultErrorCodes errorCode0x31,) = WitnetErrorsLib.parseResultError(hex"D827811831");
    (Witnet.ResultErrorCodes errorCode0x40,) = WitnetErrorsLib.parseResultError(hex"D827811840");
    (Witnet.ResultErrorCodes errorCode0x41,) = WitnetErrorsLib.parseResultError(hex"D827811841");
    (Witnet.ResultErrorCodes errorCode0x42,) = WitnetErrorsLib.parseResultError(hex"D827811842");
    Assert.equal(
      uint(errorCodeEmpty),
      uint(Witnet.ResultErrorCodes.Unknown),
      "empty error code `[]` should be `Witnet.ResultErrorCodes.Unknown`"
    );
    Assert.equal(
      uint(errorCode0x00),
      uint(Witnet.ResultErrorCodes.Unknown),
      "error code `0x00` should be `Witnet.ResultErrorCodes.Unknown`"
    );
    Assert.equal(
      uint(errorCode0x01),
      uint(Witnet.ResultErrorCodes.SourceScriptNotCBOR),
      "error code `0x01` should be `Witnet.ResultErrorCodes.SourceScriptNotCBOR`"
    );
    Assert.equal(
      uint(errorCode0x02),
      uint(Witnet.ResultErrorCodes.SourceScriptNotArray),
      "error code `0x02` should be `Witnet.ResultErrorCodes.SourceScriptNotArray`"
    );
    Assert.equal(
      uint(errorCode0x03),
      uint(Witnet.ResultErrorCodes.SourceScriptNotRADON),
      "error code `0x03` should be `Witnet.ResultErrorCodes.SourceScriptNotRADON`"
    );
    Assert.equal(
      uint(errorCode0x10),
      uint(Witnet.ResultErrorCodes.RequestTooManySources),
      "error code `0x10` should be `Witnet.ResultErrorCodes.RequestTooManySources`"
    );
    Assert.equal(
      uint(errorCode0x11),
      uint(Witnet.ResultErrorCodes.ScriptTooManyCalls),
      "error code `0x11` should be `Witnet.ResultErrorCodes.ScriptTooManyCalls`"
    );
    Assert.equal(
      uint(errorCode0x20),
      uint(Witnet.ResultErrorCodes.UnsupportedOperator),
      "error code `0x20` should be `Witnet.ResultErrorCodes.UnsupportedOperator`"
    );
    Assert.equal(
      uint(errorCode0x30),
      uint(Witnet.ResultErrorCodes.HTTP),
      "error code `0x30` should be `Witnet.ResultErrorCodes.HTTP`"
    );
    Assert.equal(
      uint(errorCode0x31),
      uint(Witnet.ResultErrorCodes.RetrievalTimeout),
      "Error code 0x31 should be `Witnet.ResultErrorCodes.RetrievalTimeout`"
    );
    Assert.equal(
      uint(errorCode0x40),
      uint(Witnet.ResultErrorCodes.Underflow),
      "error code `0x40` should be `Witnet.ResultErrorCodes.Underflow`"
    );
    Assert.equal(
      uint(errorCode0x41),
      uint(Witnet.ResultErrorCodes.Overflow),
      "error code `0x41` should be `Witnet.ResultErrorCodes.Overflow`"
    );
    Assert.equal(
      uint(errorCode0x42),
      uint(Witnet.ResultErrorCodes.DivisionByZero),
      "Error code #0x42 should be `Witnet.ResultErrorCodes.DivisionByZero`"
    );
  }

  function testErrorCodes2() external {
    (Witnet.ResultErrorCodes errorCode0x50,) = WitnetErrorsLib.parseResultError(hex"D827811850");
    (Witnet.ResultErrorCodes errorCode0x51,) = WitnetErrorsLib.parseResultError(hex"D827811851");
    (Witnet.ResultErrorCodes errorCode0x52,) = WitnetErrorsLib.parseResultError(hex"D827811852");
    (Witnet.ResultErrorCodes errorCode0x53,) = WitnetErrorsLib.parseResultError(hex"D827811853");
    (Witnet.ResultErrorCodes errorCode0x60,) = WitnetErrorsLib.parseResultError(hex"D827811860");
    (Witnet.ResultErrorCodes errorCode0x70,) = WitnetErrorsLib.parseResultError(hex"D827811870");
    (Witnet.ResultErrorCodes errorCode0x71,) = WitnetErrorsLib.parseResultError(hex"D827811871");
    (Witnet.ResultErrorCodes errorCode0xE0,) = WitnetErrorsLib.parseResultError(hex"D8278118E0");
    (Witnet.ResultErrorCodes errorCode0xE1,) = WitnetErrorsLib.parseResultError(hex"D8278118E1");
    (Witnet.ResultErrorCodes errorCode0xE2,) = WitnetErrorsLib.parseResultError(hex"D8278118E2");
    (Witnet.ResultErrorCodes errorCode0xFF,) = WitnetErrorsLib.parseResultError(hex"D8278118FF");
    Assert.equal(
      uint(errorCode0x50),
      uint(Witnet.ResultErrorCodes.NoReveals),
      "Error code #0x50 should be `Witnet.ResultErrorCodes.NoReveals`"
    );
    Assert.equal(
      uint(errorCode0x51),
      uint(Witnet.ResultErrorCodes.InsufficientConsensus),
      "Error code #0x51 should be `Witnet.ResultErrorCodes.InsufficientConsensus`"
    );
    Assert.equal(
      uint(errorCode0x52),
      uint(Witnet.ResultErrorCodes.InsufficientCommits),
      "Error code #0x52 should be `Witnet.ResultErrorCodes.InsufficientCommits`"
    );
    Assert.equal(
      uint(errorCode0x53),
      uint(Witnet.ResultErrorCodes.TallyExecution),
      "Error code #0x53 should be `Witnet.ResultErrorCodes.TallyExecution`"
    );
    Assert.equal(
      uint(errorCode0x60),
      uint(Witnet.ResultErrorCodes.MalformedReveal),
      "Error code #0x60 should be `Witnet.ResultErrorCodes.MalformedReveal`"
    );
    Assert.equal(
      uint(errorCode0x70),
      uint(Witnet.ResultErrorCodes.ArrayIndexOutOfBounds),
      "Error code #0x70 should be `Witnet.ResultErrorCodes.ArrayIndexOutOfBounds`"
    );
    Assert.equal(
      uint(errorCode0x71),
      uint(Witnet.ResultErrorCodes.MapKeyNotFound),
      "Error code #0x71 should be `Witnet.ResultErrorCodes.MapKeyNotFound`"
    );
    Assert.equal(
      uint(errorCode0xE0),
      uint(Witnet.ResultErrorCodes.BridgeMalformedRequest),
      "Error code #0xE0 should be `Witnet.ResultErrorCodes.BridgeMalformedRequest`"
    );
    Assert.equal(
      uint(errorCode0xE1),
      uint(Witnet.ResultErrorCodes.BridgePoorIncentives),
      "Error code #0xE1 should be `Witnet.ResultErrorCodes.BridgePoorIncentives`"
    );
    Assert.equal(
      uint(errorCode0xE2),
      uint(Witnet.ResultErrorCodes.BridgeOversizedResult),
      "Error code #0xE2 should be `Witnet.ResultErrorCodes.BridgeOversizedResult`"
    );
    Assert.equal(
      uint(errorCode0xFF),
      uint(Witnet.ResultErrorCodes.UnhandledIntercept),
      "Error code #0xFF should be `Witnet.ResultErrorCodes.UnhandledIntercept`"
    );
  }

  // Test decoding of `RadonError` error messages
  function testErrorMessages() external {
    (, string memory errorMessageEmpty) = WitnetErrorsLib.parseResultError(hex"D82780");
    (, string memory errorMessage0x00) = WitnetErrorsLib.parseResultError(hex"D8278100");
    (, string memory errorMessage0x01) = WitnetErrorsLib.parseResultError(hex"D827820102");
    (, string memory errorMessage0x02) = WitnetErrorsLib.parseResultError(hex"D827820203");
    (, string memory errorMessage0x03) = WitnetErrorsLib.parseResultError(hex"D827820304");
    (, string memory errorMessage0x10) = WitnetErrorsLib.parseResultError(hex"D827821005");
    (, string memory errorMessage0x11) = WitnetErrorsLib.parseResultError(hex"D8278411000708");
    (, string memory errorMessage0x20) = WitnetErrorsLib.parseResultError(hex"D8278518200108090A");
    (, string memory errorMessage0x30) = WitnetErrorsLib.parseResultError(hex"D82783183008190141");
    (, string memory errorMessage0x31) = WitnetErrorsLib.parseResultError(hex"D82782183109");
    (, string memory errorMessage0x40) = WitnetErrorsLib.parseResultError(hex"D82785184002090A0B");
    (, string memory errorMessage0x41) = WitnetErrorsLib.parseResultError(hex"D827851841000A0B0C");
    (, string memory errorMessage0x42) = WitnetErrorsLib.parseResultError(hex"D827851842010B0C0D");
    (, string memory errorMessage0xFF) = WitnetErrorsLib.parseResultError(hex"D8278118FF");
    Assert.equal(
      errorMessageEmpty,
      "Unknown error: no error code.",
      "Empty error message `[]` should be properly formatted"
    );
    Assert.equal(
      errorMessage0x00,
      "Unknown error (0x00)",
      "Error message 0x00 should be properly formatted"
    );
    Assert.equal(
      errorMessage0x01,
      "Source script #2 was not a valid CBOR value",
      "Error message for error code `0x01` (`Witnet.ResultErrorCodes.SourceScriptNotCBOR`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x02,
      "The CBOR value in script #3 was not an Array of calls",
      "Error message for error code `0x02` (`Witnet.ResultErrorCodes.SourceScriptNotArray`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x03,
      "The CBOR value in script #4 was not a valid Data Request",
      "Error message for error code `0x03` (`Witnet.ResultErrorCodes.SourceScriptNotRADON`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x10,
      "The request contained too many sources (5)",
      "Error message for error code `0x10` (`Witnet.ResultErrorCodes.RequestTooManySources`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x11,
      "Script #7 from the retrieval stage contained too many calls (8)",
      "Error message for error code `0x11` (`Witnet.ResultErrorCodes.ScriptTooManyCalls`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x20,
      "Operator code 0x0A found at call #9 in script #8 from aggregation stage is not supported",
      "Error message for error code `0x20` (`Witnet.ResultErrorCodes.UnsupportedOperator`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x30,
      "Source #8 could not be retrieved. Failed with HTTP error code: 321",
      "Error message for error code `0x30` (`Witnet.ResultErrorCodes.HTTP`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x31,
      "Source #9 could not be retrieved because of a timeout",
      "Error message for error code `0x31` (`Witnet.ResultErrorCodes.HTTP`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x40,
      "Underflow at operator code 0x0B found at call #10 in script #9 from tally stage",
      "Error message for error code `0x40` (`Witnet.ResultErrorCodes.Underflow`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x41,
      "Overflow at operator code 0x0C found at call #11 in script #10 from retrieval stage",
      "Error message for error code `0x41` (`Witnet.ResultErrorCodes.Overflow`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0x42,
      "Division by zero at operator code 0x0D found at call #12 in script #11 from aggregation stage",
      "Error message for error code `0x42` (`Witnet.ResultErrorCodes.DivisionByZero`) should be properly formatted"
    );
    Assert.equal(
      errorMessage0xFF,
      "Unknown error (0xFF)",
      "Error message for an unknown error should be properly formatted"
    );
  }

  function testBridgeErrorMessages() external { 
    (, string memory errorMessage0xE0) = WitnetErrorsLib.parseResultError(hex"D8278118E0");
    (, string memory errorMessage0xE1) = WitnetErrorsLib.parseResultError(hex"D8278118E1");
    (, string memory errorMessage0xE2) = WitnetErrorsLib.parseResultError(hex"D8278118E2");  

    Assert.equal(
      errorMessage0xE0,
      "The structure of the request is invalid and it cannot be parsed",
      "Error message failed (0xE0)"
    );
    Assert.equal(
      errorMessage0xE1,
      "The request has been rejected by the bridge node due to poor incentives",
      "Error message failed (0xE1)"
    );
    Assert.equal(
      errorMessage0xE2,
      "The request result length exceeds a bridge contract defined limit",
      "Error message failed (0xE2)"
    );
  }

}
