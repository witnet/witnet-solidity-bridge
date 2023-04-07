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
    function parseResultError(bytes memory bytecode)
        public pure
        returns (Witnet.ResultError memory _error)
    {
        uint[] memory errors = _errorsFromCborBytes(bytecode);
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
        Witnet.Result memory result = Witnet.parseResult(cborBytes);
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
        if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotCBOR
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Source script #",
                Witnet.toString(uint8(errors[1])),
                " was not a valid CBOR value"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotArray
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "The CBOR value in script #",
                Witnet.toString(uint8(errors[1])),
                " was not an Array of calls"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotRADON
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "The CBOR value in script #",
                Witnet.toString(uint8(errors[1])),
                " was not a valid Data Request"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.RequestTooManySources
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "The request contained too many sources (", 
                Witnet.toString(uint8(errors[1])), 
                ")"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.ScriptTooManyCalls
                && errors.length >= 4
        ) {
            _error.reason = string(abi.encodePacked(
                "Script #",
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
                "Operator _error.code 0x",
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
                "Source #",
                Witnet.toString(uint8(errors[1])),
                " could not be retrieved. Failed with HTTP error code: ",
                Witnet.toString(uint8(errors[2] / 100)),
                Witnet.toString(uint8(errors[2] % 100 / 10)),
                Witnet.toString(uint8(errors[2] % 10))
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.RetrievalTimeout
                && errors.length >= 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Source #",
                Witnet.toString(uint8(errors[1])),
                " could not be retrieved because of a timeout"
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.Underflow
                && errors.length >= 5
        ) {
            _error.reason = string(abi.encodePacked(
                "Underflow at operator code 0x",
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
                "Overflow at operator code 0x",
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
                "Division by zero at operator code 0x",
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
            _error.reason = "The structure of the request is invalid and it cannot be parsed";
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgePoorIncentives
        ) {
            _error.reason = "The request has been rejected by the bridge node due to poor incentives";
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgeOversizedResult
        ) {
            _error.reason = "The request result length exceeds a bridge contract defined limit";
        } else {
            _error.reason = string(abi.encodePacked(
                "Unknown error (0x",
                Witnet.toHexString(uint8(errors[0])),
                ")"
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