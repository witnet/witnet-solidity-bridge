// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./Witnet.sol";

/// @title A library for interpreting Witnet resolution errors
/// @author The Witnet Foundation.
library WitOracleResultStatusLib {

    using Witnet for bytes;
    using Witnet for uint8;
    using Witnet for uint64;
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.ResultStatus;
    using WitnetCBOR for WitnetCBOR.CBOR;

    // ================================================================================================================
    // --- Library public methods -------------------------------------------------------------------------------------

    function toString(bytes calldata _result) public pure returns (string memory) {
        Witnet.DataResult memory result = abi.decode(_result, (Witnet.DataResult));
        if (result.status == Witnet.ResultStatus.NoErrors) {
            return "No errors.";
        
        } else if (result.status == Witnet.ResultStatus.BoardAwaitingResult) {
            return "Awaiting result.";

        } else if (result.status == Witnet.ResultStatus.BoardFinalizingResult) {
            return "Finalizing result.";
        
        } else if (result.status == Witnet.ResultStatus.BoardBeingDisputed) {
            return "Being disputed.";
        
        } else if (result.status == Witnet.ResultStatus.BoardAlreadyDelivered) {
            return "Already delivered.";
        
        } else if (result.status == Witnet.ResultStatus.BoardResolutionTimeout) {
            return "Error: resolution timeout.";
        
        } else if (result.status == Witnet.ResultStatus.BridgeMalformedDataRequest) {
            return "Bridge: malformed data request.";

        } else if (result.status == Witnet.ResultStatus.BridgePoorIncentives) {
            return "Bridge: poor incentives.";

        } else if (result.status == Witnet.ResultStatus.BridgeOversizedTallyResult) {
            return "Bridge: oversized tally result.";

        } else {
            return _parseError(result);
        }
    }

    function _parseError(Witnet.DataResult memory result) private pure returns (string memory) {
        string memory _prefix;
        if (result.status.isCircumstantial()) {
            _prefix = "Circumstantial: ";
        
        } else if (result.status.poorIncentives()) {
            _prefix = "Poor incentives: ";
        
        } else if (result.status.lackOfConsensus()) {
            _prefix = "Consensus: ";
        
        } else {
            _prefix = "Critical: ";
        } 
        return string(abi.encodePacked(
            _prefix, 
            _parseErrorCode(result)
        ));
    }

    function _parseErrorCode(Witnet.DataResult memory result)
        private pure
        returns (string memory)
    {
        if (result.status == Witnet.ResultStatus.InsufficientCommits) {
            return "insufficient commits.";

        } else if (result.status == Witnet.ResultStatus.CircumstantialFailure) {
            return _parseErrorDetails(result);
        
        } else if (result.status == Witnet.ResultStatus.InsufficientMajority) {
            return "insufficient majority.";

        } else if (result.status == Witnet.ResultStatus.InsufficientReveals) {
            return "insufficient reveals.";

        } else if (
            result.status == Witnet.ResultStatus.OversizedTallyResult
                || result.status == Witnet.ResultStatus.BridgeOversizedTallyResult
        ) {
            return "oversized result.";

        } else if (result.status == Witnet.ResultStatus.InconsistentSources) {
            return "inconsistent data sources.";

        } else if (result.status == Witnet.ResultStatus.MalformedQueryResponses) {
            return string(abi.encodePacked(
                "malformed response: ",
                _parseErrorDetails(result)
            ));

        } else if (
            result.status == Witnet.ResultStatus.MalformedDataRequest 
                || result.status == Witnet.ResultStatus.BridgeMalformedDataRequest

        ) {
            return string(abi.encodePacked(
                "malformed request: ",
                _parseErrorDetails(result)
            ));

        } else if (result.status == Witnet.ResultStatus.UnhandledIntercept) {
            if (result.dataType != Witnet.RadonDataTypes.Any) {
                return string(abi.encodePacked(
                    "unhanled intercept: ",
                    _parseErrorDetails(result)
                ));
            } else {
                return "unhandled intercept.";
            }
        
        } else {
            return string(abi.encodePacked(
                "0x",
                uint8(result.status).toHexString()
            ));
        }
    }

    function _parseErrorDetails(Witnet.DataResult memory result) private pure returns (string memory) {
        if (result.dataType == Witnet.RadonDataTypes.Integer) {
            result.status = Witnet.ResultStatus(uint8(result.fetchUint()));
        } else {
            return "(unparsable error details)";
        }
        if (result.status == Witnet.ResultStatus.HttpErrors) {
            if (result.dataType == Witnet.RadonDataTypes.Integer) {
                return string(abi.encodePacked(
                    "http/",
                    result.fetchUint().toString()
                ));
            } else {
                return "unspecific http status code.";
            }

        } else if (result.status == Witnet.ResultStatus.RetrievalsTimeout) {
            return "response timeout.";

        } else if (result.status == Witnet.ResultStatus.ArrayIndexOutOfBounds) {
            if (result.dataType == Witnet.RadonDataTypes.Integer) {
                return string(abi.encodePacked(
                    "array index out of bounds: ",
                    result.fetchUint().toString()
                ));
            } else {
                return "array index out of bounds.";
            }

        } else if (result.status == Witnet.ResultStatus.MapKeyNotFound) {
            if (result.dataType == Witnet.RadonDataTypes.String) {
                return string(abi.encodePacked(
                    "map key not found: ",
                    result.fetchString()
                ));
            } else {
                return "map key not found.";
            }

        } else if (result.status == Witnet.ResultStatus.JsonPathNotFound) {
            if (result.dataType == Witnet.RadonDataTypes.String) {
                return string(abi.encodePacked(
                    "json path returned no values: ",
                    result.fetchString()
                ));
            } else {
                return "json path returned no values.";
            }
        
        } else {
            return string(abi.encodePacked(
                "0x",
                Witnet.toHexString(uint8(result.status)),
                result.dataType != Witnet.RadonDataTypes.Any 
                    ? string(abi.encodePacked(" (", _parseErrorArgs(result), ")"))
                    : ""
            ));
        }
    }

    function _parseErrorArgs(Witnet.DataResult memory result) private pure returns (string memory _str) {
        if (result.dataType == Witnet.RadonDataTypes.Any) {
            return "";
        
        } else if (result.dataType == Witnet.RadonDataTypes.String) {
            _str = string(abi.encodePacked("'", result.fetchString(), "', "));

        } else if (result.dataType == Witnet.RadonDataTypes.Integer) {
            _str = string(abi.encodePacked(result.fetchUint().toString(), ", "));

        } else {
            _str = "?, ";
        }
        return string(abi.encodePacked(_str, _parseErrorArgs(result)));
    }
}
