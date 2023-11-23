// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./Witnet.sol";

/// @title A library for interpreting Witnet resolution errors
/// @author The Witnet Foundation.
library WitnetErrorsLib {

    using Witnet for uint8;
    using Witnet for uint256;
    using WitnetCBOR for WitnetCBOR.CBOR;

    // ================================================================================================================
    // --- Library public methods -------------------------------------------------------------------------------------
    
    /// @notice Extract error code and description string from given Witnet.Result.
    /// @dev Client contracts should wrap this function into a try-catch foreseeing potential parsing errors.
    /// @return _error Witnet.ResultError data struct containing error code and description.
    function asError(Witnet.Result memory result)
        public pure
        returns (Witnet.ResultError memory _error)
    {
         return _fromErrorArray(
            _errorsFromResult(result)
        );
    }

    function asResultError(Witnet.ResultStatus _status, bytes memory _cborBytes)
        public pure
        returns (Witnet.ResultError memory)
    {
        if (_status == Witnet.ResultStatus.Awaiting) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetRequestBoard: not yet solved"
            });
        } else if (_status == Witnet.ResultStatus.Void) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetRequestBoard: unknown query"
            });
        } else {
            return resultErrorFromCborBytes(_cborBytes);
        }
    }

    /// @notice Extract error code and description string from given CBOR-encoded value.
    /// @dev Client contracts should wrap this function into a try-catch foreseeing potential parsing errors.
    /// @return _error Witnet.ResultError data struct containing error code and description.
    function resultErrorFromCborBytes(bytes memory cborBytes)
        public pure
        returns (Witnet.ResultError memory _error)
    {
        WitnetCBOR.CBOR[] memory errors = _errorsFromCborBytes(cborBytes);
        return _fromErrorArray(errors);
    }


    // ================================================================================================================
    // --- Library private methods ------------------------------------------------------------------------------------

    /// @dev Extract error codes from a CBOR-encoded `bytes` value.
    /// @param cborBytes CBOR-encode `bytes` value.
    /// @return The `uint[]` error parameters as decoded from the `Witnet.Result`.
    function _errorsFromCborBytes(bytes memory cborBytes)
        private pure
        returns(WitnetCBOR.CBOR[] memory)
    {
        Witnet.Result memory result = Witnet.resultFromCborBytes(cborBytes);
        return _errorsFromResult(result);
    }

    /// @dev Extract error codes from a Witnet.Result value.
    /// @param result An instance of `Witnet.Result`.
    /// @return The `uint[]` error parameters as decoded from the `Witnet.Result`.
    function _errorsFromResult(Witnet.Result memory result)
        private pure
        returns (WitnetCBOR.CBOR[] memory)
    {
        require(!result.success, "no errors");
        return result.value.readArray();
    }

    /// @dev Extract Witnet.ResultErrorCodes and error description from given array of CBOR values.
    function _fromErrorArray(WitnetCBOR.CBOR[] memory errors)
        private pure
        returns (Witnet.ResultError memory _error)
    {
        if (errors.length < 2) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "Unknown error: no error code was found."
            });
        }
        else {
            _error.code = Witnet.ResultErrorCodes(errors[0].readUint());
        }
        // switch on _error.code
        if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotCBOR
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Radon: invalid CBOR value."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotArray
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Radon: CBOR value expected to be an array of calls."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.SourceScriptNotRADON
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Radon: CBOR value expected to be a data request."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.RequestTooManySources
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Radon: too many sources."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.ScriptTooManyCalls
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Radon: too many calls."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.UnsupportedOperator
                && errors.length > 3
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Radon: unsupported '",
                errors[2].readString(),
                "' for input type '",
                errors[1].readString(),
                "'."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.HTTP
                && errors.length > 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Retrieval: HTTP/",
                errors[1].readUint().toString(), 
                " error."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.RetrievalTimeout
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Retrieval: timeout."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.Underflow
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Aggregation: math underflow."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.Overflow
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Aggregation: math overflow."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.DivisionByZero
                && errors.length > 1
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Aggregation: division by zero."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgeMalformedRequest
        ) {
            _error.reason = "Witnet: Bridge: malformed data request cannot be processed.";
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgePoorIncentives
        ) {
            _error.reason = "Witnet: Bridge: rejected due to poor witnessing incentives.";
        } else if (
            _error.code == Witnet.ResultErrorCodes.BridgeOversizedResult
        ) {
            _error.reason = "Witnet: Bridge: rejected due to poor bridging incentives.";
        } else if (
            _error.code == Witnet.ResultErrorCodes.InsufficientConsensus
                && errors.length > 3
        ) {
            uint reached = (errors[1].additionalInformation == 25
                ? uint(int(errors[1].readFloat16() / 10 ** 4))
                : uint(int(errors[1].readFloat64() / 10 ** 15))
            );
            uint expected = (errors[2].additionalInformation == 25
                ? uint(int(errors[2].readFloat16() / 10 ** 4))
                : uint(int(errors[2].readFloat64() / 10 ** 15))
            );
            _error.reason = string(abi.encodePacked(
                "Witnet: Tally: insufficient consensus: ",
                reached.toString(), 
                "% <= ",
                expected.toString(), 
                "%."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.InsufficientCommits
        ) {
            _error.reason = "Witnet: Tally: insufficient commits.";
        } else if (
            _error.code == Witnet.ResultErrorCodes.TallyExecution
                && errors.length > 3
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Tally: execution error: ",
                errors[2].readString(),
                "."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.ArrayIndexOutOfBounds
                && errors.length > 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Aggregation: tried to access a value from an array with an index (",
                errors[1].readUint().toString(),
                ") out of bounds."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.MapKeyNotFound
                && errors.length > 2
        ) {
            _error.reason = string(abi.encodePacked(
                "Witnet: Aggregation: tried to access a value from a map with a key (\"",
                errors[1].readString(),
                "\") that was not found."
            ));
        } else if (
            _error.code == Witnet.ResultErrorCodes.NoReveals
        ) {
            _error.reason = "Witnet: Tally: no reveals.";
        } else if (
            _error.code == Witnet.ResultErrorCodes.MalformedReveal
        ) {
            _error.reason = "Witnet: Tally: malformed reveal.";
        } else if (
            _error.code == Witnet.ResultErrorCodes.UnhandledIntercept
        ) {
            _error.reason = "Witnet: Tally: unhandled intercept.";
        } else {
            _error.reason = string(abi.encodePacked(
                "Unhandled error: 0x",
                Witnet.toHexString(uint8(_error.code)),
                errors.length > 2
                    ? string(abi.encodePacked(" (", uint(errors.length - 1).toString(), " params)."))
                    : "."
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
            return "Retrieval";
        } else if (stageIndex == 1) {
            return "Aggregation";
        } else if (stageIndex == 2) {
            return "Tally";
        } else {
            return "(unknown)";
        }
    }
}