// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../WitOracleRadonRegistry.sol";
import "../interfaces/IWitOracleConsumer.sol";
import "../interfaces/IWitOracleEvents.sol";
import "../interfaces/IWitOracleReporter.sol";
import "../libs/Witnet.sol";

/// @title Witnet Request Board base data model library
/// @author The Witnet Foundation.
library WitOracleDataLib {  

    using Witnet for Witnet.QueryRequest;
    using WitnetCBOR for WitnetCBOR.CBOR;

    bytes32 internal constant _WIT_ORACLE_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint256 nonce;
        mapping (uint => Witnet.Query) queries;
        mapping (address => bool) reporters;
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function data() internal pure returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WIT_ORACLE_DATA_SLOTHASH
        }
    }

    function isReporter(address addr) internal view returns (bool) {
        return data().reporters[addr];
    }

    /// Saves query response into storage.
    function saveQueryResponse(
            uint256 queryId,
            uint32  resultTimestamp,
            bytes32 resultTallyHash,
            bytes memory resultCborBytes
        ) internal
    {
        seekQuery(queryId).response = Witnet.QueryResponse({
            reporter: msg.sender,
            finality: uint64(block.number),
            resultTimestamp: resultTimestamp,
            resultTallyHash: resultTallyHash,
            resultCborBytes: resultCborBytes
        });
    }

    /// Gets query storage by query id.
    function seekQuery(uint256 queryId) internal view returns (Witnet.Query storage) {
      return data().queries[queryId];
    }

    /// Gets the Witnet.QueryRequest part of a given query.
    function seekQueryRequest(uint256 queryId) internal view returns (Witnet.QueryRequest storage) {
        return data().queries[queryId].request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function seekQueryResponse(uint256 queryId) internal view returns (Witnet.QueryResponse storage) {
        return data().queries[queryId].response;
    }

    function seekQueryStatus(uint256 queryId) internal view returns (Witnet.QueryStatus) {
        Witnet.Query storage __query = data().queries[queryId];
        if (__query.response.resultTimestamp != 0) {
            if (block.number >= __query.response.finality) {
                return Witnet.QueryStatus.Finalized;
            } else {
                return Witnet.QueryStatus.Reported;
            }
        } else if (__query.request.requester != address(0)) {
            return Witnet.QueryStatus.Posted;
        } else {
            return Witnet.QueryStatus.Unknown;
        }
    }

    function seekQueryResponseStatus(uint256 queryId) internal view returns (Witnet.QueryResponseStatus) {
        Witnet.QueryStatus _queryStatus = seekQueryStatus(queryId);
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            bytes storage __cborValues = data().queries[queryId].response.resultCborBytes;
            if (__cborValues.length > 0) {
                // determine whether stored result is an error by peeking the first byte
                return (__cborValues[0] == bytes1(0xd8)
                    ? Witnet.QueryResponseStatus.Error 
                    : Witnet.QueryResponseStatus.Ready
                );
            } else {
                // the result is final but delivered to the requesting address
                return Witnet.QueryResponseStatus.Delivered;
            }
        } else if (_queryStatus == Witnet.QueryStatus.Posted) {
            return Witnet.QueryResponseStatus.Awaiting;
        } else if (_queryStatus == Witnet.QueryStatus.Reported) {
            return Witnet.QueryResponseStatus.Finalizing;
        } else {
            return Witnet.QueryResponseStatus.Void;
        }
    }

    // ================================================================================================================
    // --- Public functions -------------------------------------------------------------------------------------------

    function extractWitnetDataRequests(WitOracleRadonRegistry registry, uint256[] calldata queryIds)
        public view
        returns (bytes[] memory bytecodes)
    {
        bytecodes = new bytes[](queryIds.length);
        for (uint _ix = 0; _ix < queryIds.length; _ix ++) {
            if (seekQueryStatus(queryIds[_ix]) != Witnet.QueryStatus.Unknown) {
                Witnet.QueryRequest storage __request = data().queries[queryIds[_ix]].request;
                if (__request.radonRadHash != bytes32(0)) {
                    bytecodes[_ix] = registry.bytecodeOf(
                        __request.radonRadHash,
                        __request.radonSLA
                    );
                } else {
                    bytecodes[_ix] = registry.bytecodeOf(
                        __request.radonBytecode,
                        __request.radonSLA 
                    );
                }
            }
        }
    }

    function notInStatusRevertMessage(Witnet.QueryStatus self) public pure returns (string memory) {
        if (self == Witnet.QueryStatus.Posted) {
            return "query not in Posted status";
        } else if (self == Witnet.QueryStatus.Reported) {
            return "query not in Reported status";
        } else if (self == Witnet.QueryStatus.Finalized) {
            return "query not in Finalized status";
        } else {
            return "bad mood";
        }
    }

    function reportResult(
            uint256 evmGasPrice,
            uint256 queryId,
            uint32  resultTimestamp,
            bytes32 resultTallyHash,
            bytes calldata resultCborBytes
        )
        public returns (uint256 evmReward)
    {
        // read requester address and whether a callback was requested:
        Witnet.QueryRequest storage __request = seekQueryRequest(queryId);
                
        // read query EVM reward:
        evmReward = __request.evmReward;
        
        // set EVM reward right now as to avoid re-entrancy attacks:
        __request.evmReward = 0; 

        // determine whether a callback is required
        if (__request.gasCallback > 0) {
            (
                uint256 evmCallbackActualGas,
                bool evmCallbackSuccess,
                string memory evmCallbackRevertMessage
            ) = reportResultCallback(
                __request.requester,
                __request.gasCallback,
                queryId,
                resultTimestamp,
                resultTallyHash,
                resultCborBytes
            );
            if (evmCallbackSuccess) {
                // => the callback run successfully
                emit IWitOracleEvents.WitOracleQueryReponseDelivered(
                    queryId,
                    evmGasPrice,
                    evmCallbackActualGas
                );
            } else {
                // => the callback reverted
                emit IWitOracleEvents.WitOracleQueryResponseDeliveryFailed(
                    queryId,
                    evmGasPrice,
                    evmCallbackActualGas,
                    bytes(evmCallbackRevertMessage).length > 0 
                        ? evmCallbackRevertMessage
                        : "WitOracleDataLib: callback exceeded gas limit",
                    resultCborBytes
                );
            }
            // upon delivery, successfull or not, the audit trail is saved into storage, 
            // but not the actual result which was intended to be passed over to the requester:
            saveQueryResponse(
                queryId, 
                resultTimestamp, 
                resultTallyHash, 
                hex""
            );
        } else {
            // => no callback is involved
            emit IWitOracleEvents.WitOracleQueryResponse(
                queryId, 
                evmGasPrice
            );
            // write query result and audit trail data into storage 
            saveQueryResponse(
                queryId,
                resultTimestamp,
                resultTallyHash,
                resultCborBytes
            );
        }
    }

    function reportResultCallback(
            address evmRequester,
            uint256 evmCallbackGasLimit,
            uint256 queryId,
            uint64  resultTimestamp,
            bytes32 resultTallyHash,
            bytes calldata resultCborBytes
        )
        public returns (
            uint256 evmCallbackActualGas, 
            bool evmCallbackSuccess, 
            string memory evmCallbackRevertMessage
        )
    {
        evmCallbackActualGas = gasleft();
        if (resultCborBytes[0] == bytes1(0xd8)) {
            WitnetCBOR.CBOR[] memory _errors = WitnetCBOR.fromBytes(resultCborBytes).readArray();
            if (_errors.length < 2) {
                // try to report result with unknown error:
                try IWitOracleConsumer(evmRequester).reportWitOracleResultError{gas: evmCallbackGasLimit}(
                    queryId,
                    resultTimestamp,
                    resultTallyHash,
                    block.number,
                    Witnet.ResultErrorCodes.Unknown,
                    WitnetCBOR.CBOR({
                        buffer: WitnetBuffer.Buffer({ data: hex"", cursor: 0}),
                        initialByte: 0,
                        majorType: 0,
                        additionalInformation: 0,
                        len: 0,
                        tag: 0
                    })
                ) {
                    evmCallbackSuccess = true;
                } catch Error(string memory err) {
                    evmCallbackRevertMessage = err;
                }
            } else {
                // try to report result with parsable error:
                try IWitOracleConsumer(evmRequester).reportWitOracleResultError{gas: evmCallbackGasLimit}(
                    queryId,
                    resultTimestamp,
                    resultTallyHash,
                    block.number,
                    Witnet.ResultErrorCodes(_errors[0].readUint()),
                    _errors[0]
                ) {
                    evmCallbackSuccess = true;
                } catch Error(string memory err) {
                    evmCallbackRevertMessage = err; 
                }
            }
        } else {
            // try to report result result with no error :
            try IWitOracleConsumer(evmRequester).reportWitOracleResultValue{gas: evmCallbackGasLimit}(
                queryId,
                resultTimestamp,
                resultTallyHash,
                block.number,
                WitnetCBOR.fromBytes(resultCborBytes)
            ) {
                evmCallbackSuccess = true;
            } catch Error(string memory err) {
                evmCallbackRevertMessage = err;
            } catch (bytes memory) {}
        }
        evmCallbackActualGas -= gasleft();
    }
}
