// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitOracleRadonRegistry.sol";
import "../interfaces/IWitOracleAdminACLs.sol";
import "../interfaces/IWitOracleConsumer.sol";
import "../interfaces/IWitOracleEvents.sol";
import "../interfaces/IWitOracleExperimental.sol";
import "../interfaces/IWitOracleLegacy.sol";
import "../interfaces/IWitOracleTrustableReporter.sol";
import "../interfaces/IWitOracleTrustlessReporter.sol";
import "../libs/Witnet.sol";

/// @title Witnet Request Board base data model library
/// @author The Witnet Foundation.
library WitOracleDataLib {  

    using Witnet for Witnet.DataPushReport;
    // using Witnet for Witnet.DataPullReport;
    using Witnet for Witnet.QuerySLA;
    
    using WitnetCBOR for WitnetCBOR.CBOR;

    bytes32 internal constant _WIT_ORACLE_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint256 nonce;
        mapping (Witnet.QueryId => Witnet.Query) queries;
        mapping (address => bool) reporters;
        mapping (address => mapping (Witnet.RadonHash => Committee)) committees;
    }

    struct Committee {
        bytes32 hash;
        Witnet.ServiceProvider[] members;
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

    function hashify(
            Witnet.QuerySLA memory querySLA, 
            address evmRequester, 
            bytes32 radHash
        ) 
        internal view
    returns (bytes32) {
        return (
            data().committees[evmRequester][Witnet.RadonHash.wrap(radHash)].hash != bytes32(0)
                ? querySLA.hashify()
                : keccak256(abi.encode(
                    querySLA.hashify(),
                    data().committees[evmRequester][Witnet.RadonHash.wrap(radHash)].hash
                )
            )
        );
    }

    /// Gets query storage by query id.
    function seekQuery(Witnet.QueryId queryId) internal view returns (Witnet.Query storage) {
      return data().queries[queryId];
    }

    /// Gets the Witnet.QueryRequest part of a given query.
    function seekQueryRequest(Witnet.QueryId queryId) internal view returns (Witnet.QueryRequest storage) {
        return data().queries[queryId].request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function seekQueryResponse(Witnet.QueryId queryId) internal view returns (Witnet.QueryResponse storage) {
        return data().queries[queryId].response;
    }

    function intoDataResult(Witnet.QueryResponse memory queryResponse, Witnet.QueryStatus queryStatus)
        internal pure
        returns (Witnet.DataResult memory _result)
    {
        _result.drTxHash = Witnet.TransactionHash.wrap(queryResponse.resultDrTxHash);
        _result.timestamp = Witnet.Timestamp.wrap(queryResponse.resultTimestamp);
        if (queryResponse.resultCborBytes.length > 0) {
            _result.value = WitnetCBOR.fromBytes(queryResponse.resultCborBytes);
            _result.dataType = Witnet.peekRadonDataType(_result.value);
        }
        if (queryStatus == Witnet.QueryStatus.Finalized) {
            if (queryResponse.resultCborBytes.length > 0) {
                // determine whether stored result is an error by peeking the first byte
                if (queryResponse.resultCborBytes[0] == bytes1(0xd8)) {
                    if (
                        _result.dataType == Witnet.RadonDataTypes.Array
                            && WitnetCBOR.readLength(_result.value.buffer, _result.value.additionalInformation) >= 1
                    ) {
                        if (Witnet.peekRadonDataType(_result.value) != Witnet.RadonDataTypes.Integer) {
                            _result.status = Witnet.ResultStatus(_result.value.readInt());
                            _result.dataType = Witnet.peekRadonDataType(_result.value);
                        
                        } else {
                            _result.status = Witnet.ResultStatus.UnhandledIntercept;
                        }
                    } else {
                        _result.status = Witnet.ResultStatus.UnhandledIntercept;
                    }            
                } else {
                    _result.status = Witnet.ResultStatus.NoErrors;
                }
            } else {
                // the result is final but was delivered to some consuming contract:
                _result.status = Witnet.ResultStatus.BoardAlreadyDelivered;
            }
        
        } else if (queryStatus == Witnet.QueryStatus.Reported) {
            _result.status = Witnet.ResultStatus.BoardFinalizingResult;

        } else if (
            queryStatus == Witnet.QueryStatus.Posted
                || queryStatus == Witnet.QueryStatus.Delayed
        ) {
            _result.status = Witnet.ResultStatus.BoardAwaitingResult;
        
        } else if (
            queryStatus == Witnet.QueryStatus.Expired
                || queryStatus == Witnet.QueryStatus.Disputed
        ) {
            _result.status = Witnet.ResultStatus.BoardResolutionTimeout;
        
        } else {
            _result.status = Witnet.ResultStatus.UnhandledIntercept;
        }
    }

    function intoString(Witnet.QueryStatus _status) internal pure returns (string memory) {
        if (_status == Witnet.QueryStatus.Posted) {
            return "Posted";
        } else if (_status == Witnet.QueryStatus.Reported) {
            return "Reported";
        } else if (_status == Witnet.QueryStatus.Finalized) {
            return "Finalized";
        } else if (_status == Witnet.QueryStatus.Delayed) {
            return "Delayed";
        } else if (_status == Witnet.QueryStatus.Expired) {
            return "Expired";
        } else if (_status == Witnet.QueryStatus.Disputed) {
            return "Disputed";
        } else {
            return "Unknown";
        }
    }


    /// =======================================================================
    /// --- IWitOracleAdminACLs -----------------------------------------------

    function isReporter(address addr) internal view returns (bool) {
        return data().reporters[addr];
    }

    function setReporters(address[] calldata reporters) public {
        for (uint ix = 0; ix < reporters.length; ix ++) {
            data().reporters[reporters[ix]] = true;
        }
        emit IWitOracleAdminACLs.ReportersSet(reporters);
    }

    function unsetReporters(address[] calldata reporters) public {
        for (uint ix = 0; ix < reporters.length; ix ++) {
            data().reporters[reporters[ix]] = false;
        }
        emit IWitOracleAdminACLs.ReportersUnset(reporters);
    }

    
    /// =======================================================================
    /// --- IWitOracle --------------------------------------------------------

    function extractDataResult(
            Witnet.QueryResponse calldata queryResponse, 
            Witnet.QueryStatus queryStatus
        )
        public pure 
        returns (Witnet.DataResult memory)
    {
        return intoDataResult(queryResponse, queryStatus);
    }

    function deleteQuery(Witnet.QueryId queryId) 
        public 
        returns (Witnet.QueryEvmReward _evmPayback) 
    {
        Witnet.Query storage __query = seekQuery(queryId);
        require(
            msg.sender == __query.request.requester,
            "not the requester"
        );
        Witnet.QueryStatus _queryStatus = getQueryStatus(queryId);
        if (
            _queryStatus != Witnet.QueryStatus.Expired
                && _queryStatus != Witnet.QueryStatus.Finalized
        ) {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                toString(_queryStatus)
            )));
        }
        _evmPayback = __query.reward;
        delete data().queries[queryId];
    }   

    function getQueryStatus(Witnet.QueryId queryId) public view returns (Witnet.QueryStatus) {
        Witnet.Query storage __query = seekQuery(queryId);
        if (__query.response.resultTimestamp != 0) {
            return Witnet.QueryStatus.Finalized;
            
        } else if (__query.request.requester != address(0)) {
            return Witnet.QueryStatus.Posted;
        
        } else {
            return Witnet.QueryStatus.Unknown;
        }
    }

    function getQueryResult(Witnet.QueryId queryId) public view returns (Witnet.DataResult memory _result) {
        Witnet.QueryStatus _queryStatus = getQueryStatus(queryId);
        return intoDataResult(seekQueryResponse(queryId), _queryStatus);
    }
    
    function getQueryResultStatus(Witnet.QueryId queryId) public view returns (Witnet.ResultStatus) {
        Witnet.QueryStatus _queryStatus = getQueryStatus(queryId);
        Witnet.QueryResponse storage __response = seekQueryResponse(queryId);
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            if (__response.resultCborBytes.length > 0) {
                // determine whether stored result is an error by peeking the first byte
                if (__response.resultCborBytes[0] == bytes1(0xd8)) {
                    WitnetCBOR.CBOR[] memory _error = WitnetCBOR.fromBytes(__response.resultCborBytes).readArray();
                    if (_error.length < 2) {
                        return Witnet.ResultStatus.UnhandledIntercept;
                    } else {
                        return Witnet.ResultStatus(_error[0].readUint());
                    }
                } else {
                    return Witnet.ResultStatus.NoErrors;
                }

            } else {
                // the result is final but was delivered to some consuming contract:
                return Witnet.ResultStatus.BoardAlreadyDelivered;
            }
        
        } else if (_queryStatus == Witnet.QueryStatus.Reported) {
            return Witnet.ResultStatus.BoardFinalizingResult;

        } else if (
            _queryStatus == Witnet.QueryStatus.Posted
                || _queryStatus == Witnet.QueryStatus.Delayed
        ) {
            return Witnet.ResultStatus.BoardAwaitingResult;
        
        } else if (
            _queryStatus == Witnet.QueryStatus.Expired
                || _queryStatus == Witnet.QueryStatus.Disputed
        ) {
            return Witnet.ResultStatus.BoardResolutionTimeout;
        
        } else {
            return Witnet.ResultStatus.UnhandledIntercept;
        }
    }

    function getQueryResponseStatus(Witnet.QueryId queryId)
        public view 
        returns (IWitOracleLegacy.QueryResponseStatus)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatus(queryId);
        
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            bytes storage __cborValues = WitOracleDataLib.seekQueryResponse(queryId).resultCborBytes;
            if (__cborValues.length > 0) {
                // determine whether stored result is an error by peeking the first byte
                return (__cborValues[0] == bytes1(0xd8)
                    ? IWitOracleLegacy.QueryResponseStatus.Error 
                    : IWitOracleLegacy.QueryResponseStatus.Ready
                );
            
            } else {
                // the result is final but delivered to the requesting address
                return IWitOracleLegacy.QueryResponseStatus.Delivered;
            }
        
        } else if (_queryStatus == Witnet.QueryStatus.Posted) {
            return IWitOracleLegacy.QueryResponseStatus.Awaiting;
        
        } else if (_queryStatus == Witnet.QueryStatus.Expired) {
            return IWitOracleLegacy.QueryResponseStatus.Expired;
        
        } else {
            return IWitOracleLegacy.QueryResponseStatus.Void;
        }
    }

    
    /// ================================================================================
    /// --- IWitOracleTrustableReporter ------------------------------------------------

    function extractRadonRequests(
            WitOracleRadonRegistry registry, 
            uint256[] calldata queryIds
        )
        public view
        returns (bytes[] memory bytecodes)
    {
        bytecodes = new bytes[](queryIds.length);
        for (uint _ix = 0; _ix < queryIds.length; _ix ++) {
            Witnet.Query storage __query = seekQuery(Witnet.QueryId.wrap(queryIds[_ix]));
            bytecodes[_ix] = (__query.request.radonHash != bytes32(0)
                ? registry.bytecodeOf(__query.request.radonHash, __query.slaParams)
                : registry.bytecodeOf(__query.request.radonBytecode, __query.slaParams)
            );
        }
    }

    function reportResult(
            address evmReporter,
            uint256 evmGasPrice,
            uint64  evmFinalityBlock,
            uint256 queryId,
            uint64  witDrResultTimestamp,
            bytes32 witDrTxHash,
            bytes calldata witDrResultCborBytes
        )
        public returns (uint256 evmReward)
    {
        // read requester address and whether a callback was requested:
        Witnet.Query storage __query = seekQuery(Witnet.QueryId.wrap(queryId));

        // read query EVM reward:
        evmReward = Witnet.QueryEvmReward.unwrap(__query.reward);

        // set EVM reward right now as to avoid re-entrancy attacks:
        __query.reward = Witnet.QueryEvmReward.wrap(0);

        // determine whether a callback is required
        if (__query.request.callbackGas > 0) {
            (uint256 _evmCallbackActualGas, bool _evmCallbackSuccess, string memory _evmCallbackRevertMessage) = __reportResultCallback(
                __query.request.requester,
                __query.request.callbackGas,
                evmFinalityBlock,
                queryId,
                witDrResultTimestamp,
                witDrTxHash,
                witDrResultCborBytes
            );
            if (_evmCallbackSuccess) {
                // => the callback run successfully
                emit IWitOracleEvents.WitOracleQueryReponseDelivered(
                    queryId,
                    evmGasPrice,
                    _evmCallbackActualGas
                );
            } else {
                // => the callback reverted
                emit IWitOracleEvents.WitOracleQueryResponseDeliveryFailed(
                    queryId,
                    evmGasPrice,
                    _evmCallbackActualGas,
                    bytes(_evmCallbackRevertMessage).length > 0 
                        ? _evmCallbackRevertMessage
                        : "WitOracleDataLib: callback exceeded gas limit",
                    witDrResultCborBytes
                );
            }
            // upon delivery, successfull or not, the audit trail is saved into storage, 
            // but not the actual result which was intended to be passed over to the requester:
            __saveQueryResponse(
                evmReporter,
                evmFinalityBlock,
                queryId, 
                witDrResultTimestamp, 
                witDrTxHash,
                hex""
            );
        } else {
            // => no callback is involved
            emit IWitOracleEvents.WitOracleQueryResponse(
                queryId, 
                evmGasPrice
            );
            // write query result and audit trail data into storage 
            __saveQueryResponse(
                evmReporter,
                evmFinalityBlock,
                queryId,
                witDrResultTimestamp,
                witDrTxHash,
                witDrResultCborBytes
            );
        }
    }

    function __reportResultCallback(
            address requester,
            uint24  evmCallbackGasLimit,
            uint64  evmFinalityBlock,
            uint256 queryId,
            uint64  witDrResultTimestamp,
            bytes32 witDrTxHash,
            bytes calldata witDrResultCborBytes
        )
        private returns (
            uint256 evmCallbackActualGas, 
            bool evmCallbackSuccess, 
            string memory evmCallbackRevertMessage
        )
    {
        evmCallbackActualGas = gasleft();
        Witnet.DataResult memory _result = intoDataResult(
            Witnet.QueryResponse({
                reporter: address(0),
                resultTimestamp: witDrResultTimestamp,
                resultDrTxHash: witDrTxHash,
                resultCborBytes: witDrResultCborBytes,
                disputer: address(0), _0: 0
            }),
            evmFinalityBlock == block.number ? Witnet.QueryStatus.Finalized : Witnet.QueryStatus.Reported
        );
        try IWitOracleConsumer(requester).reportWitOracleQueryResult{
            gas: evmCallbackGasLimit
        } (
            Witnet.QueryId.wrap(queryId),
            _result
        ) {
            evmCallbackSuccess = true;
        
        } catch Error(string memory err) {
            evmCallbackRevertMessage = err;
        
        } catch (bytes memory) {
            evmCallbackRevertMessage = "callback revert";
        }
        evmCallbackActualGas -= gasleft();
    }

    /// Saves query response into storage.
    function __saveQueryResponse(
            address evmReporter,
            uint64  evmFinalityBlock,
            uint256 queryId,
            uint64  witDrResultTimestamp,
            bytes32 witDrTxHash,
            bytes memory witDrResultCborBytes
        ) private
    {
        Witnet.Query storage __query = seekQuery(Witnet.QueryId.wrap(queryId));
        __query.checkpoint = Witnet.BlockNumber.wrap(evmFinalityBlock);
        __query.response.reporter = evmReporter; 
        __query.response.resultTimestamp = witDrResultTimestamp;
        __query.response.resultDrTxHash = witDrTxHash;
        __query.response.resultCborBytes = witDrResultCborBytes;
    }


    /// =======================================================================
    /// --- IWitOracleExperimental --------------------------------------------

    function extractDDR(
            WitOracleRadonRegistry registry,
            Witnet.QueryId queryId
        )
        public view
        returns (IWitOracleExperimental.DDR memory)
    {
        Witnet.Query storage __query = seekQuery(queryId);
        
        bytes memory _radonBytecode;
        bytes32 _radonHash = __query.request.radonHash;
        if (_radonHash == bytes32(0)) {
            _radonBytecode = __query.request.radonBytecode;
            _radonHash = registry.hashOf(_radonBytecode);
        } else {
            _radonBytecode = registry.bytecodeOf(_radonHash);
        }
        
        Witnet.ServiceProvider[] memory _providers = data().committees
            [__query.request.requester]
            [Witnet.RadonHash.wrap(_radonHash)]
            .members;

        Witnet.QuerySLA memory _querySLA = __query.slaParams;
        
        return IWitOracleExperimental.DDR({
            queryId: queryId,
            queryHash: __query.hash,
            queryEvmReward: __query.reward,
            queryParams: IWitOracleExperimental.QueryParams({
                witResultMaxSize: _querySLA.witResultMaxSize,
                witCommitteeSize: _querySLA.witCommitteeSize,
                witInclusionFees: _querySLA.witInclusionFees,
                providers: _providers
            }),
            radonBytecode: _radonBytecode
        });
    }

    
    /// =======================================================================
    /// --- Other public helper methods ---------------------------------------

    function notInStatusRevertMessage(Witnet.QueryStatus self) public pure returns (string memory) {
        if (self == Witnet.QueryStatus.Posted) {
            return "not in Posted status";
        } else if (self == Witnet.QueryStatus.Reported) {
            return "not in Reported status";
        } else if (self == Witnet.QueryStatus.Finalized) {
            return "not in Finalized status";
        } else {
            return "bad mood";
        }
    }

    function settle(Committee storage self, Witnet.ServiceProvider[] calldata members) public returns (bytes32 hash) {
        if (members.length > 0) {
            hash = keccak256(abi.encodePacked(members));
            self.hash = hash;
            self.members = members;
        } else {
            delete self.members;
            self.hash = bytes32(0);
        }
    }

    function toString(Witnet.QueryStatus _status) public pure returns (string memory) {
        return intoString(_status);
    }

}
