// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetV2.sol";

/// @title A library for interpreting Witnet resolution errors
/// @author The Witnet Foundation.
library WitnetErrorsLib {

    using Witnet for bytes;
    using Witnet for uint8;
    using Witnet for uint256;
    using Witnet for Witnet.ResultErrorCodes;
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

    function asResultError(WitnetV2.ResponseStatus _status, bytes memory _cborBytes)
        public pure
        returns (Witnet.ResultError memory)
    {
        if (
            _status == WitnetV2.ResponseStatus.Error
                || _status == WitnetV2.ResponseStatus.Ready
        ) {
            return resultErrorFromCborBytes(_cborBytes);
        } else if (_status == WitnetV2.ResponseStatus.Finalizing) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetErrorsLib: not yet finalized"
            });
        } if (_status == WitnetV2.ResponseStatus.Awaiting) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetErrorsLib: not yet reported"
            });
        } else {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetErrorsLib: unknown query"
            });
        }
    }

    function resultErrorCodesFromCborBytes(bytes memory cborBytes)
        public pure
        returns (
            Witnet.ResultErrorCodes _code, 
            Witnet.ResultErrorCodes _subcode
        )
    {
        WitnetCBOR.CBOR[] memory _errors = _errorsFromResult(cborBytes.toWitnetResult());
        if (_errors.length > 1) {
            _code = Witnet.ResultErrorCodes(_errors[0].readUint());
            if (_errors.length > 2) {
                _subcode = Witnet.ResultErrorCodes(_errors[1].readUint());
            } 
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
        return _errorsFromResult(cborBytes.toWitnetResult());
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
                reason: "Critical: no error code was found."
            });
        } else {
            _error.code = Witnet.ResultErrorCodes(errors[0].readUint());
        }
        string memory _prefix;
        if (_error.code.isCircumstantial()) {
            _prefix = "Circumstantial: ";
        } else if (_error.code.poorIncentives()) {
            _prefix = "Poor incentives: ";
        } else if (_error.code.lackOfConsensus()) {
            _prefix = "Consensual: ";
        } else {
            _prefix = "Critical: ";
        } 
        _error.reason = string(abi.encodePacked(_prefix, _stringify(_error.code, errors)));
    }

    function _stringify(Witnet.ResultErrorCodes code, WitnetCBOR.CBOR[] memory args)
        private pure
        returns (string memory)
    {
        if (code == Witnet.ResultErrorCodes.InsufficientCommits) {
            return "insufficient commits.";

        } else if (
            code == Witnet.ResultErrorCodes.CircumstantialFailure
                && args.length > 2
        ) {
            return _stringify(args[1].readUint(), args);
        
        } else if (code == Witnet.ResultErrorCodes.InsufficientMajority) {
            return "insufficient majority.";

        } else if (code == Witnet.ResultErrorCodes.InsufficientReveals) {
            return "insufficient reveals.";

        } else if (code == Witnet.ResultErrorCodes.BridgePoorIncentives) {
            return "as for the bridge.";

        } else if (
            code == Witnet.ResultErrorCodes.OversizedTallyResult
                || code == Witnet.ResultErrorCodes.BridgeOversizedTallyResult
        ) {
            return "oversized result.";

        } else if (code == Witnet.ResultErrorCodes.InconsistentSources) {
            return "inconsistent sources.";

        } else if (
            code == Witnet.ResultErrorCodes.MalformedResponses
                && args.length > 2
        ) {
            return string(abi.encodePacked(
                "malformed response: ",
                _stringify(args[1].readUint(), args)
            ));

        } else if (
            code == Witnet.ResultErrorCodes.MalformedDataRequest 
                || code == Witnet.ResultErrorCodes.BridgeMalformedDataRequest

        ) {
            if (args.length > 2) {
                return string(abi.encodePacked(
                    "malformed request: ",
                    _stringify(args[1].readUint(), args)
                ));
            } else {
                return "malformed request.";
            }

        } else if (code == Witnet.ResultErrorCodes.UnhandledIntercept) {
            if (args.length > 2) {
                return string(abi.encodePacked(
                    "unhandled intercept on tally (+",
                    (args.length - 2).toString(),
                    " args)."
                ));
            } else {
                return "unhandled intercept on tally.";
            }
        
        } else {
            return string(abi.encodePacked(
                "0x",
                uint8(code).toHexString()
            ));
        }
    }

    function _stringify(uint subcode, WitnetCBOR.CBOR[] memory args)
        private pure 
        returns (string memory)
    {
        Witnet.ResultErrorCodes _code = Witnet.ResultErrorCodes(subcode);

        // circumstantial subcodes:
        if (_code == Witnet.ResultErrorCodes.HttpErrors) {
            if (args.length > 3) {
                return string(abi.encodePacked(
                    "http/",
                    args[2].readUint().toString()
                ));
            } else {
                return "unspecific http status code.";
            }

        } else if (_code == Witnet.ResultErrorCodes.RetrievalsTimeout) {
            return "response timeout.";

        } else if (_code == Witnet.ResultErrorCodes.ArrayIndexOutOfBounds) {
            if (args.length > 3) {
                return string(abi.encodePacked(
                    "array index out of bounds: ",
                    args[2].readUint().toString()
                ));
            } else {
                return "array index out of bounds.";
            }

        } else if (_code == Witnet.ResultErrorCodes.MapKeyNotFound) {
            if (args.length > 3) {
                return string(abi.encodePacked(
                    "map key not found: ",
                    args[2].readString()
                ));
            } else {
                return "map key not found.";
            }

        } else if (_code == Witnet.ResultErrorCodes.JsonPathNotFound) {
            if (args.length > 3) {
                return string(abi.encodePacked(
                    "json path returned no values: ",
                    args[2].readString()
                ));
            } else {
                return "json path returned no values.";
            }
        
        } else {
            return string(abi.encodePacked(
                "0x",
                Witnet.toHexString(uint8(_code)),
                args.length > 3
                    ? string(abi.encodePacked(" (+", uint(args.length - 3).toString(), " args)"))
                    : ""
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