pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/Witnet.sol";


contract WitnetTest {
  using Witnet for Witnet.Result;

  // Test the `Witnet.stageNames` pure method, which gives strings with the names for the different Witnet request
  // stages
  function testStageNames() public {
    Assert.equal(Witnet.stageName(0), "retrieval", "Stage name for stage #1 should be \"retrieval\"");
    Assert.equal(Witnet.stageName(1), "aggregation", "Stage name for stage #1 should be \"aggregation\"");
    Assert.equal(Witnet.stageName(2), "tally", "Stage name for stage #1 should be \"tally\"");
  }

  // Test decoding of `RadonError` error codes
  function testErrorCodes() public {
    Witnet.ErrorCodes errorCode0 = Witnet.resultFromCborBytes(hex"D8278100").asErrorCode();
    Witnet.ErrorCodes errorCode1 = Witnet.resultFromCborBytes(hex"D8278101").asErrorCode();
    Witnet.ErrorCodes errorCode2 = Witnet.resultFromCborBytes(hex"D8278102").asErrorCode();
    Witnet.ErrorCodes errorCode3 = Witnet.resultFromCborBytes(hex"D8278103").asErrorCode();
    Witnet.ErrorCodes errorCode4 = Witnet.resultFromCborBytes(hex"D8278104").asErrorCode();
    Witnet.ErrorCodes errorCode5 = Witnet.resultFromCborBytes(hex"D8278105").asErrorCode();
    Witnet.ErrorCodes errorCode6 = Witnet.resultFromCborBytes(hex"D8278106").asErrorCode();
    Witnet.ErrorCodes errorCode7 = Witnet.resultFromCborBytes(hex"D8278107").asErrorCode();
    Witnet.ErrorCodes errorCode8 = Witnet.resultFromCborBytes(hex"D8278108").asErrorCode();
    Witnet.ErrorCodes errorCode9 = Witnet.resultFromCborBytes(hex"D8278109").asErrorCode();
    Witnet.ErrorCodes errorCode10 = Witnet.resultFromCborBytes(hex"D827810A").asErrorCode();
    Witnet.ErrorCodes errorCode11 = Witnet.resultFromCborBytes(hex"D827810B").asErrorCode();
    Witnet.ErrorCodes errorCode12 = Witnet.resultFromCborBytes(hex"D827810C").asErrorCode();
    Assert.equal(
      uint(errorCode0),
      uint(Witnet.ErrorCodes.Unknown),
      "Error code #0 should be `Witnet.ErrorCodes.Unknown`"
    );
    Assert.equal(
      uint(errorCode1),
      uint(Witnet.ErrorCodes.SourceScriptNotCBOR),
      "Error code #1 should be `Witnet.ErrorCodes.SourceScriptNotCBOR`"
    );
    Assert.equal(
      uint(errorCode2),
      uint(Witnet.ErrorCodes.SourceScriptNotArray),
      "Error code #2 should be `Witnet.ErrorCodes.SourceScriptNotArray`"
    );
    Assert.equal(
      uint(errorCode3),
      uint(Witnet.ErrorCodes.SourceScriptNotRADON),
      "Error code #3 should be `Witnet.ErrorCodes.SourceScriptNotRADON`"
    );
    Assert.equal(
      uint(errorCode4),
      uint(Witnet.ErrorCodes.RequestTooManySources),
      "Error code #4 should be `Witnet.ErrorCodes.RequestTooManySources`"
    );
    Assert.equal(
      uint(errorCode5),
      uint(Witnet.ErrorCodes.ScriptTooManyCalls),
      "Error code #5 should be `Witnet.ErrorCodes.ScriptTooManyCalls`"
    );
    Assert.equal(
      uint(errorCode6),
      uint(Witnet.ErrorCodes.UnsupportedOperator),
      "Error code #6 should be `Witnet.ErrorCodes.UnsupportedOperator`"
    );
    Assert.equal(
      uint(errorCode7),
      uint(Witnet.ErrorCodes.HTTP),
      "Error code #7 should be `Witnet.ErrorCodes.HTTP`"
    );
    Assert.equal(
      uint(errorCode8),
      uint(Witnet.ErrorCodes.Underflow),
      "Error code #8 should be `Witnet.ErrorCodes.Underflow`"
    );
    Assert.equal(
      uint(errorCode9),
      uint(Witnet.ErrorCodes.Overflow),
      "Error code #9 should be `Witnet.ErrorCodes.Overflow`"
    );
    Assert.equal(
      uint(errorCode10),
      uint(Witnet.ErrorCodes.DivisionByZero),
      "Error code #10 should be `Witnet.ErrorCodes.DivisionByZero`"
    );
    Assert.equal(
      uint(errorCode11),
      uint(Witnet.ErrorCodes.RuntimeError),
      "Error code #11 should be `Witnet.ErrorCodes.RuntimeError`"
    );
    Assert.equal(
      uint(errorCode12),
      uint(Witnet.ErrorCodes.InsufficientConsensusError),
      "Error code #12 should be `Witnet.ErrorCodes.InsufficientConsensusError`"
    );
  }

  // Test decoding of `RadonError` error messages
  function testErrorMessages() public {
    (, string memory errorMessage0) = Witnet.resultFromCborBytes(hex"D8278100").asErrorMessage();
    (, string memory errorMessage1) = Witnet.resultFromCborBytes(hex"D827820102").asErrorMessage();
    (, string memory errorMessage2) = Witnet.resultFromCborBytes(hex"D827820203").asErrorMessage();
    (, string memory errorMessage3) = Witnet.resultFromCborBytes(hex"D827820304").asErrorMessage();
    (, string memory errorMessage4) = Witnet.resultFromCborBytes(hex"D827820405").asErrorMessage();
    (, string memory errorMessage5) = Witnet.resultFromCborBytes(hex"D8278405000708").asErrorMessage();
    (, string memory errorMessage6) = Witnet.resultFromCborBytes(hex"D82785060108090A").asErrorMessage();
    (, string memory errorMessage7) = Witnet.resultFromCborBytes(hex"D827830708190141").asErrorMessage();
    (, string memory errorMessage8) = Witnet.resultFromCborBytes(hex"D827850802090A0B").asErrorMessage();
    (, string memory errorMessage9) = Witnet.resultFromCborBytes(hex"D8278509000A0B0C").asErrorMessage();
    (, string memory errorMessage10) = Witnet.resultFromCborBytes(hex"D827850A010B0C0D").asErrorMessage();
    (, string memory errorMessage11) = Witnet.resultFromCborBytes(hex"D827850B020C0D0E").asErrorMessage();
    (, string memory errorMessage12) = Witnet.resultFromCborBytes(hex"D827830C0D0E").asErrorMessage();
    (, string memory errorMessage255) = Witnet.resultFromCborBytes(hex"D8278118FF").asErrorMessage();
    Assert.equal(
      errorMessage0,
      "Unknown error (0)",
      "Error message #0 should be properly formatted"
    );
    Assert.equal(
      errorMessage1,
      "Source script #2 was not a valid CBOR value",
      "Error message #1 (`Witnet.ErrorCodes.SourceScriptNotCBOR`) should be properly formatted"
    );
    Assert.equal(
      errorMessage2,
      "The CBOR value in script #3 was not an Array of calls",
      "Error message #2 (`Witnet.ErrorCodes.SourceScriptNotArray`) should be properly formatted"
    );
    Assert.equal(
      errorMessage3,
      "The CBOR value in script #4 was not a valid RADON script",
      "Error message #3 (`Witnet.ErrorCodes.SourceScriptNotRADON`) should be properly formatted"
    );
    Assert.equal(
      errorMessage4,
      "The request contained too many sources (5)",
      "Error message #4 (`Witnet.ErrorCodes.RequestTooManySources`) should be properly formatted"
    );
    Assert.equal(
      errorMessage5,
      "Script #7 from the retrieval stage contained too many calls (8)",
      "Error message #5 (`Witnet.ErrorCodes.ScriptTooManyCalls`) should be properly formatted"
    );
    Assert.equal(
      errorMessage6,
      "Operator code 10 found at call #9 in script #8 from aggregation stage is not supported",
      "Error message #6 (`Witnet.ErrorCodes.UnsupportedOperator`) should be properly formatted"
    );
    Assert.equal(
      errorMessage7,
      "Source #8 could not be retrieved. Failed with HTTP error code: 321",
      "Error message #7 (`Witnet.ErrorCodes.HTTP`) should be properly formatted"
    );
    Assert.equal(
      errorMessage8,
      "Underflow at operator code 11 found at call #10 in script #9 from tally stage",
      "Error message #8 (`Witnet.ErrorCodes.Underflow`) should be properly formatted"
    );
    Assert.equal(
      errorMessage9,
      "Overflow at operator code 12 found at call #11 in script #10 from retrieval stage",
      "Error message #9 (`Witnet.ErrorCodes.Overflow`) should be properly formatted"
    );
    Assert.equal(
      errorMessage10,
      "Division by zero at operator code 13 found at call #12 in script #11 from aggregation stage",
      "Error message #10 (`Witnet.ErrorCodes.DivisionByZero`) should be properly formatted"
    );
    Assert.equal(
      errorMessage11,
      "Unspecified runtime error at operator code 14 found at call #13 in script #12 from tally stage",
      "Error message #11 (`Witnet.ErrorCodes.RuntimeError`) should be properly formatted"
    );
    Assert.equal(
      errorMessage12,
      "Insufficient consensus. Required: 13. Achieved: 14",
      "Error message #12 (`Witnet.ErrorCodes.InsufficientConsensusError`) should be properly formatted"
    );
    Assert.equal(
      errorMessage255,
      "Unknown error (255)",
      "Error message for an unknown error should be properly formatted"
    );
  }
}
