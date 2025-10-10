// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IWitOracleQueriableConsumer.sol";
import "../interfaces/IWitOracleQueriableEvents.sol";
import "../interfaces/IWitOracleQueriableExperimental.sol";
import "../interfaces/IWitOracleRadonRegistry.sol";
import "../interfaces/IWitOracleTrustableAdmin.sol";
import "../interfaces/IWitOracleQueriableTrustableReporter.sol";

import "../interfaces/legacy/IWitOracleLegacy.sol";

import "../libs/Witnet.sol";

/// @title Witnet Request Board base data model library
/// @author The Witnet Foundation.
library WitOracleDataLib {  

    using Witnet for Witnet.DataPushReport;
    using Witnet for Witnet.QuerySLA;
    using Witnet for Witnet.RadonHash;
    using Witnet for Witnet.Timestamp;
    
    using WitnetCBOR for WitnetCBOR.CBOR;

    bytes32 internal constant _WIT_ORACLE_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint64 nonce;
        mapping (uint256 => Query) queries;
        mapping (address => bool) reporters;
        mapping (address => mapping (Witnet.RadonHash => Committee)) committees;
    }

    struct Query {
        QueryRequest request;
        QueryResponse response;
        Witnet.QuerySLA slaParams;
        Witnet.QueryUUID uuid;
        Witnet.QueryEvmReward reward;
        Witnet.BlockNumber checkpoint;
    }

    struct QueryRequest {
        address requester; uint24 callbackGas; uint72 _0;
        bytes radonBytecode;
        bytes32 radonHash; 
        uint256 _1;
    }

    struct QueryResponse {
        address reporter; uint32 _0; uint64 resultTimestamp;
        bytes32 resultDrTxHash;
        bytes resultCborBytes;
        address disputer;
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
            Witnet.RadonHash radonHash
        ) 
        internal view
        returns (bytes32)
    {
        return (
            data().committees[evmRequester][radonHash].hash != bytes32(0)
                ? querySLA.hashify()
                : keccak256(abi.encode(
                    querySLA.hashify(),
                    data().committees[evmRequester][radonHash].hash
                )
            )
        );
    }

    /// Gets query storage by query id.
    function seekQuery(uint256 queryId) internal view returns (Query storage) {
      return data().queries[queryId];
    }

    /// Gets the Witnet.QueryRequest part of a given query.
    function seekQueryRequest(uint256 queryId) internal view returns (QueryRequest storage) {
        return data().queries[queryId].request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function seekQueryResponse(uint256 queryId) internal view returns (QueryResponse storage) {
        return data().queries[queryId].response;
    }

    function intoDataResult(
            QueryResponse memory queryResponse, 
            Witnet.QueryStatus queryStatus,
            uint64 finalityBlock
        )
        internal pure
        returns (Witnet.DataResult memory _result)
    {
        _result.drTxHash = Witnet.TransactionHash.wrap(queryResponse.resultDrTxHash);
        if (queryResponse._0 > 0) {
            _result.finality = (
                queryResponse._0 | uint64(
                    (queryResponse.resultTimestamp & 0xffffffff) << 32
                )
            );
            _result.timestamp = Witnet.Timestamp.wrap(queryResponse.resultTimestamp >> 32);
        } else {
            _result.finality = finalityBlock;
            _result.timestamp = Witnet.Timestamp.wrap(queryResponse.resultTimestamp);
        }
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
                        if (Witnet.peekRadonDataType(_result.value) == Witnet.RadonDataTypes.Integer) {
                            _result.status = Witnet.ResultStatus(_result.value.readInt());
                        
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
                _result.status = Witnet.ResultStatus.NoErrors;
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
    /// --- IWitOracleTrustableAdmin -----------------------------------------------

    function isReporter(address addr) internal view returns (bool) {
        return data().reporters[addr];
    }

    function setReporters(address[] calldata reporters) public {
        for (uint ix = 0; ix < reporters.length; ix ++) {
            data().reporters[reporters[ix]] = true;
        }
        emit IWitOracleTrustableAdmin.ReportersSet(reporters);
    }

    function unsetReporters(address[] calldata reporters) public {
        for (uint ix = 0; ix < reporters.length; ix ++) {
            data().reporters[reporters[ix]] = false;
        }
        emit IWitOracleTrustableAdmin.ReportersUnset(reporters);
    }

    
    /// =======================================================================
    /// --- IWitOracle --------------------------------------------------------

    function extractDataResult(
            QueryResponse memory queryResponse, 
            Witnet.QueryStatus queryStatus,
            uint64 finalityBlock
        )
        public pure 
        returns (Witnet.DataResult memory)
    {
        return intoDataResult(queryResponse, queryStatus, finalityBlock);
    }

    function parseDataReport(
            Witnet.DataPushReport calldata _dataPushReport, 
            bytes calldata _signature
        )
        public view
        returns (
            address _evmReporter, 
            Witnet.DataResult memory _data
        )
    {
        _evmReporter = Witnet.recoverEvmAddr(_signature, _dataPushReport.digest());
        require(data().reporters[_evmReporter], "WitOracleDataLib: invalid signature");
        _data = extractDataResult(
            QueryResponse({
                reporter: _evmReporter, 
                resultCborBytes: _dataPushReport.resultCborBytes,
                resultDrTxHash: Witnet.TransactionHash.unwrap(_dataPushReport.witDrTxHash),
                resultTimestamp: Witnet.Timestamp.unwrap(_dataPushReport.resultTimestamp),
                disputer: address(0), _0: 0
            }), 
            Witnet.QueryStatus.Finalized,
            uint64(block.number)
        );
    }

    /// =======================================================================
    /// --- IWitOracleQueriable -----------------------------------------------

    function deleteQuery(uint256 queryId) 
        public 
        returns (Witnet.QueryEvmReward _evmPayback) 
    {
        WitOracleDataLib.Query storage __query = seekQuery(queryId);
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

    function getQuery(Witnet.QueryId queryId) public view returns (Witnet.Query memory) {
        WitOracleDataLib.Query storage __query = data().queries[Witnet.QueryId.unwrap(queryId)];
        Witnet.QueryUUID _uuid;
        Witnet.QueryEvmReward _reward;
        Witnet.BlockNumber _checkpoint;
        if (__query.request._1 > 0) {
            // read from v2 layout
            _checkpoint = Witnet.BlockNumber.wrap(__query.response._0);
            _reward = Witnet.QueryEvmReward.wrap(__query.request._0);

        } else if (__query.request.radonBytecode.length <= 65535) {
            // read from v3 layout
            _checkpoint = __query.checkpoint;
            _reward = __query.reward;
            _uuid = __query.uuid;
        }
        return Witnet.Query({
            request: getQueryRequest(queryId),
            response: getQueryResponse(queryId),
            slaParams: __query.slaParams,
            uuid: __query.uuid,
            reward: __query.reward,
            checkpoint: __query.checkpoint
        });
    }

    function getQueryRequest(Witnet.QueryId queryId) public view returns (Witnet.QueryRequest memory) {
        WitOracleDataLib.Query storage __query = data().queries[Witnet.QueryId.unwrap(queryId)];
        if (__query.request.radonBytecode.length > 65535) {
            // read from v1 layout
            return Witnet.QueryRequest({
                requester: address(0),
                callbackGas: 0,
                radonBytecode: hex"",
                radonHash: Witnet.RadonHash.wrap(__query.request.radonHash)
            });
        } else {
            return Witnet.QueryRequest({
                requester: __query.request.requester,
                callbackGas: __query.request.callbackGas,
                radonBytecode: __query.request.radonBytecode,
                radonHash: Witnet.RadonHash.wrap(__query.request.radonHash)
            });
        }
    }

    function getQueryResponse(Witnet.QueryId queryId) public view returns (Witnet.QueryResponse memory) {
        WitOracleDataLib.Query storage __query = data().queries[Witnet.QueryId.unwrap(queryId)];
        if (__query.request.radonBytecode.length > 65535) {
            // read from v1 layout
            return Witnet.QueryResponse({
                reporter: address(0),
                resultTimestamp: Witnet.Timestamp.wrap(0),
                resultDrTxHash: Witnet.TransactionHash.wrap(0),
                resultCborBytes: __query.response.resultCborBytes,
                disputer: address(0)
            });
        } else if (__query.request._1 > 0) {
            // read from v2 layout
            return Witnet.QueryResponse({
                reporter: __query.response.reporter,
                resultTimestamp: Witnet.Timestamp.wrap(__query.response.resultTimestamp >> 32),
                resultDrTxHash: Witnet.TransactionHash.wrap(__query.response.resultDrTxHash),
                resultCborBytes: __query.response.resultCborBytes,
                disputer: address(0)
            });
        } else {
            return Witnet.QueryResponse({
                reporter: __query.response.reporter,
                resultTimestamp: Witnet.Timestamp.wrap(__query.response.resultTimestamp),
                resultDrTxHash: Witnet.TransactionHash.wrap(__query.response.resultDrTxHash),
                resultCborBytes: __query.response.resultCborBytes,
                disputer: __query.response.disputer
            });
        }
    }

    function getQueryStatus(uint256 queryId) public view returns (Witnet.QueryStatus) {
        WitOracleDataLib.Query storage __query = seekQuery(queryId);
        if (__query.response.resultTimestamp != 0) {
            return Witnet.QueryStatus.Finalized;
            
        } else if (__query.request.requester != address(0)) {
            return Witnet.QueryStatus.Posted;
        
        } else {
            return Witnet.QueryStatus.Unknown;
        }
    }

    function getQueryResult(uint256 queryId) public view returns (Witnet.DataResult memory _result) {
        Witnet.QueryStatus _queryStatus = getQueryStatus(queryId);
        WitOracleDataLib.Query storage __query = seekQuery(queryId);
        return intoDataResult(
            __query.response,
            _queryStatus,
            Witnet.BlockNumber.unwrap(__query.checkpoint)
        );
    }
    
    function getQueryResultStatus(uint256 queryId) public view returns (Witnet.ResultStatus) {
        Witnet.QueryStatus _queryStatus = getQueryStatus(queryId);
        QueryResponse storage __response = seekQueryResponse(queryId);
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
                }
            }
            return Witnet.ResultStatus.NoErrors;
        
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

    function getQueryResponseStatus(uint256 queryId)
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
    /// --- IWitOracleQueriableTrustableReporter ---------------------------------------

    function extractRadonBytecodes(
            IWitOracleRadonRegistry registry, 
            Witnet.QueryId[] calldata queryIds
        )
        public view
        returns (bytes[] memory bytecodes)
    {
        bytecodes = new bytes[](queryIds.length);
        for (uint _ix = 0; _ix < queryIds.length; _ix ++) {
            uint256 _queryId = Witnet.QueryId.unwrap(queryIds[_ix]);
            WitOracleDataLib.Query storage __query = seekQuery(_queryId);
            bytecodes[_ix] = (__query.request.radonHash != bytes32(0)
                ? registry.bytecodeOf(Witnet.RadonHash.wrap(__query.request.radonHash), __query.slaParams)
                : registry.bytecodeOf(__query.request.radonBytecode, __query.slaParams)
            );
        }
    }

    function reportResult(
            address evmReporter,
            uint256 evmGasPrice,
            uint64  evmFinalityBlock,
            uint256 queryId,
            Witnet.Timestamp resultTimestamp,
            Witnet.TransactionHash witDrTxHash,
            bytes calldata resultCborBytes
        )
        public returns (uint256 evmReward)
    {
        // read requester address and whether a callback was requested:
        WitOracleDataLib.Query storage __query = seekQuery(queryId);

        // read query EVM reward:
        evmReward = Witnet.QueryEvmReward.unwrap(__query.reward);

        // set EVM reward right now as to avoid re-entrancy attacks:
        __query.reward = Witnet.QueryEvmReward.wrap(0);

        // determine whether a callback is required
        if (__query.request.callbackGas > 0) {
            (
                uint256 _evmCallbackActualGas, 
                bool _evmCallbackSuccess, 
                string memory _evmCallbackRevertMessage
            ) = __reportResultCallback(
                evmReporter,
                __query.request.requester,
                __query.request.callbackGas,
                evmFinalityBlock,
                Witnet.QueryId.wrap(uint64(queryId)),
                resultTimestamp,
                witDrTxHash,
                resultCborBytes
            );
            if (_evmCallbackSuccess) {
                // => the callback run successfully
                emit IWitOracleQueriableEvents.WitOracleQueryReportDelivery(
                    Witnet.QueryId.wrap(uint64(queryId)),
                    __query.request.requester,
                    evmGasPrice,
                    _evmCallbackActualGas
                );
            } else {
                // => the callback reverted
                emit IWitOracleQueriableEvents.WitOracleResportDeliveryFailed(
                    Witnet.QueryId.wrap(uint64(queryId)),
                    __query.request.requester,
                    evmGasPrice,
                    _evmCallbackActualGas,
                    bytes(_evmCallbackRevertMessage).length > 0 
                        ? _evmCallbackRevertMessage
                        : "WitOracleDataLib: callback exceeded gas limit",
                    resultCborBytes
                );
            }
            // upon delivery, successfull or not, the audit trail is saved into storage, 
            // but not the actual result which was intended to be passed over to the requester:
            __saveQueryResponse(
                evmReporter,
                evmFinalityBlock,
                queryId,
                resultTimestamp, 
                witDrTxHash,
                hex""
            );
        } else {
            // => no callback is involved
            emit IWitOracleQueriableEvents.WitOracleQueryReport(
                Witnet.QueryId.wrap(uint64(queryId)),
                evmGasPrice
            );
            // write query result and audit trail data into storage 
            __saveQueryResponse(
                evmReporter,
                evmFinalityBlock,
                queryId,
                resultTimestamp,
                witDrTxHash,
                resultCborBytes
            );
        }
    }

    function __reportResultCallback(
            address evmReporter,
            address evmRequester,
            uint24  evmCallbackGasLimit,
            uint64  evmFinalityBlock,
            Witnet.QueryId queryId,
            Witnet.Timestamp resultTimestamp,
            Witnet.TransactionHash witDrTxHash,
            bytes calldata resultCborBytes
        )
        private returns (
            uint256 evmCallbackActualGas, 
            bool evmCallbackSuccess, 
            string memory evmCallbackRevertMessage
        )
    {
        evmCallbackActualGas = gasleft();
        Witnet.DataResult memory _result = intoDataResult(
            QueryResponse({
                reporter: evmReporter,
                resultTimestamp: Witnet.Timestamp.unwrap(resultTimestamp),
                resultDrTxHash: Witnet.TransactionHash.unwrap(witDrTxHash),
                resultCborBytes: resultCborBytes,
                disputer: address(0), _0: 0
            }),
            evmFinalityBlock <= block.number ? Witnet.QueryStatus.Finalized : Witnet.QueryStatus.Reported,
            evmFinalityBlock
        );
        try IWitOracleQueriableConsumer(evmRequester).reportWitOracleQueryResult{
            gas: evmCallbackGasLimit
        } (
            Witnet.QueryId.unwrap(queryId),
            abi.encode(_result)
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
            Witnet.Timestamp resultTimestamp,
            Witnet.TransactionHash witDrTxHash,
            bytes memory resultCborBytes
        ) private
    {
        WitOracleDataLib.Query storage __query = seekQuery(queryId);
        __query.checkpoint = Witnet.BlockNumber.wrap(evmFinalityBlock);
        __query.response.reporter = evmReporter; 
        __query.response.resultTimestamp = Witnet.Timestamp.unwrap(resultTimestamp);
        __query.response.resultDrTxHash = Witnet.TransactionHash.unwrap(witDrTxHash);
        __query.response.resultCborBytes = resultCborBytes;
    }


    /// =======================================================================
    /// --- IWitOracleQueriableExperimental -----------------------------------

    function extractDelegatedDataRequest(
            IWitOracleRadonRegistry registry,
            Witnet.QueryId queryId
        )
        public view
        returns (IWitOracleQueriableExperimental.DDR memory)
    {
        WitOracleDataLib.Query storage __query = seekQuery(Witnet.QueryId.unwrap(queryId));
        
        bytes memory _radonBytecode;
        Witnet.RadonHash _radonHash = Witnet.RadonHash.wrap(__query.request.radonHash);
        if (_radonHash.isZero()) {
            _radonBytecode = __query.request.radonBytecode;
            _radonHash = registry.hashOf(_radonBytecode);
        } else {
            _radonBytecode = registry.lookupRadonRequestBytecode(_radonHash);
        }
        
        Witnet.ServiceProvider[] memory _providers = data().committees
            [__query.request.requester]
            [_radonHash]
            .members;

        Witnet.QuerySLA memory _querySLA = __query.slaParams;
        
        return IWitOracleQueriableExperimental.DDR({
            queryId: queryId,
            queryUUID: __query.uuid,
            queryEvmReward: __query.reward,
            queryParams: IWitOracleQueriableExperimental.QueryParams({
                witResultMaxSize: _querySLA.witResultMaxSize,
                witCommitteeSize: _querySLA.witCommitteeSize,
                witUnitaryReward: _querySLA.witUnitaryReward,
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
