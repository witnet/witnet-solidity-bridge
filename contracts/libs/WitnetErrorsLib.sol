// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./Witnet.sol";

/// @title A library for interpreting Witnet resolution errors
/// @author The Witnet Foundation.
library WitnetErrorsLib {

    // ================================================================================================================
    // --- Library public methods -------------------------------------------------------------------------------------
    
    /// @notice Extract error code and description string from given Witnet.Result.
    /// @dev Client contracts should wrap this function into a try-catch foreseeing potential parsing errors.
    /// @return _error Witnet.ResultError data struct containing error code and description.
    function asError(Witnet.Result memory result)
        public pure
        returns (Witnet.ResultError memory _error)
    {
         uint[] memory errors = _errorsFromResult(result);
         return _fromErrorCodes(errors);
    }

    /// @notice Extract error code and description string from given CBOR-encoded value.
    /// @dev Client contracts should wrap this function into a try-catch foreseeing potential parsing errors.
    /// @return _error Witnet.ResultError data struct containing error code and description.
    function resultErrorFromCborBytes(bytes memory cborBytes)
        public pure
        returns (Witnet.ResultError memory _error)
    {
        uint[] memory errors = _errorsFromCborBytes(cborBytes);
        return _fromErrorCodes(errors);
    }


    // ================================================================================================================
    // --- Library private methods ------------------------------------------------------------------------------------

    /// @dev Extract error codes from a CBOR-encoded `bytes` value.
    /// @param cborBytes CBOR-encode `bytes` value.
    /// @return The `uint[]` error parameters as decoded from the `Witnet.Result`.
    function _errorsFromCborBytes(bytes memory cborBytes)
        private pure
        returns(uint[] memory)
    {
        Witnet.Result memory result = Witnet.resultFromCborBytes(cborBytes);
        return _errorsFromResult(result);
    }

    /// @dev Extract error codes from a Witnet.Result value.
    /// @param result An instance of `Witnet.Result`.
    /// @return The `uint[]` error parameters as decoded from the `Witnet.Result`.
    function _errorsFromResult(Witnet.Result memory result)
        private pure
        returns (uint[] memory)
    {
        require(!result.success, "no errors");
        return Witnet.asUintArray(result);
    }

    /// @dev Extract Witnet.ResultErrorCodes and error description from given array of uints.
    function _fromErrorCodes(uint[] memory errors)
        private pure
        returns (Witnet.ResultError memory _error)
    {
        if (errors.length == 0) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "Unknown error: no error code was found."
            });
        }
        else {
            _error.code = Witnet.ResultErrorCodes(errors[0]);
        }
        // switch on _error.code
        if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotCBOR
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Syntax error: source script #",
                Witnet.toString(uint8(errors[1])),
                " was not a valid CBOR value"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotArray
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Syntax error: the CBOR value in script #",
                Witnet.toString(uint8(errors[1])),
                " was not an array of calls"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotRADON
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Syntax error: the CBOR value in script #",
                Witnet.toString(uint8(errors[1])),
                " was not a valid Data Request"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.RequestTooManySources
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Complexity error: the request contained too many sources (", 
                Witnet.toString(uint8(errors[1])), 
                ")"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.ScriptTooManyCalls
                && errors.length >= 4
        ) {
            _error.reason = string(abi.encodePacked(
                "Complexity error: script #",
                Witnet.toString(uint8(errors[2])),
                " from the ",
                _stageName(uint8(errors[1])),
                " stage contained too many calls (",
                Witnet.toString(uint8(errors[3])),
                ")"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.UnsupportedOperator
                && errors.length >= 5
        ) {
            _error.reason = string(abi.encodePacked(
                "Radon script: opcode 0x",
                Witnet.toHexString(uint8(errors[4])),
                " found at call #",
                Witnet.toString(uint8(errors[3])),
                " in script #",
                Witnet.toString(uint8(errors[2])),
                " from ",
                _stageName(uint8(errors[1])),
                " stage is not supported"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.HTTP
                && errors.length >= 3
        ) {
            _error.reason = string(abi.encodePacked(
                "External error: source #",
                Witnet.toString(uint8(errors[1])),
                " failed with HTTP error code: ",
                Witnet.toString(uint8(errors[2] / 100)),
                Witnet.toString(uint8(errors[2] % 100 / 10)),
                Witnet.toString(uint8(errors[2] % 10))
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.RetrievalTimeout
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "External error: source #",
                Witnet.toString(uint8(errors[1])),
                " could not be retrieved because of a timeout"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.Underflow
                && errors.length >= 5
        ) {
            _error.reason = string(abi.encodePacked(
                "Math error: underflow at opcode 0x",
                Witnet.toHexString(uint8(errors[4])),
                " found at call #",
                Witnet.toString(uint8(errors[3])),
                " in script #",
                Witnet.toString(uint8(errors[2])),
                " from ",
                _stageName(uint8(errors[1])),
                " stage"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.Overflow
                && errors.length >= 5
        ) {
            _error.reason = string(abi.encodePacked(
                "Math error: overflow at opcode 0x",
                Witnet.toHexString(uint8(errors[4])),
                " found at call #",
                Witnet.toString(uint8(errors[3])),
                " in script #",
                Witnet.toString(uint8(errors[2])),
                " from ",
                _stageName(uint8(errors[1])),
                " stage"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.DivisionByZero
                && errors.length >= 5
        ) {
            _error.reason = string(abi.encodePacked(
                "Math error: division by zero at opcode 0x",
                Witnet.toHexString(uint8(errors[4])),
                " found at call #",
                Witnet.toString(uint8(errors[3])),
                " in script #",
                Witnet.toString(uint8(errors[2])),
                " from ",
                _stageName(uint8(errors[1])),
                " stage"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgeMalformedRequest
        ) {
            _error.reason = "Bridge error: malformed data request cannot be processed";
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgePoorIncentives
        ) {
            _error.reason = "Bridge error: rejected due to poor witnessing incentives";
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgeOversizedResult
        ) {
            _error.reason = "Bridge error: rejected due to poor bridging incentives";
        } else if (
            _error.code == Witnet.ResultErrorCodes.RetrievalTimeout
        ) {
            _error.reason = "External error: at least one of the sources timed out";
        } else if (
            _error.code == Witnet.ResultErrorCodes.InsufficientConsensus
        ) {
            _error.reason = "Insufficient witnessing consensus";
        } else if (
            _error.code == Witnet.ResultErrorCodes.InsufficientCommits
        ) {
            _error.reason = "Insufficient witnessing commits";
        } else if (
            _error.code == Witnet.ResultErrorCodes.TallyExecution
        ) {
            _error.reason = "Tally execution error";
        } else if (
            _error.code == Witnet.ResultErrorCodes.ArrayIndexOutOfBounds
        ) {
            _error.reason = "Radon script: tried to access a value from an array with an index out of bounds";
        } else if (
            _error.code == Witnet.ResultErrorCodes.MapKeyNotFound
        ) {
            _error.reason = "Radon script: tried to access a value from a map with a key that does not exist";
        } else {
            _error.reason = string(abi.encodePacked(
                "Unhandled error: 0x",
                Witnet.toHexString(uint8(errors[0]))
            ));
        }
    }

    /// @notice Convert a stage index number into the name of the matching Witnet request stage.
    /// @param stageIndex A `uint64` identifying the index of one of the Witnet request stages.
    /// @return The name of the matching stage.
    function _stageName(uint64 stageIndex)
        private pure
        returns (string memory)
    {
        if (stageIndex == 0) {
            return "retrieval";
        } else if (stageIndex == 1) {
            return "aggregation";
        } else if (stageIndex == 2) {
            return "tally";
        } else {
            return "unknown";
        }
    }
}