// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitOracleRadonRegistry.sol";
import "../interfaces/IWitOracleAdminACLs.sol";
import "../interfaces/IWitOracleBlocks.sol";
import "../interfaces/IWitOracleConsumer.sol";
import "../interfaces/IWitOracleEvents.sol";
import "../interfaces/IWitOracleLegacy.sol";
import "../interfaces/IWitOracleTrustableReporter.sol";
import "../interfaces/IWitOracleTrustlessReporter.sol";
import "../libs/Witnet.sol";
import "../patterns/Escrowable.sol";

/// @title Witnet Request Board base data model library
/// @author The Witnet Foundation.
library WitOracleDataLib {  

    using Witnet for Witnet.Beacon;
    using Witnet for Witnet.DataPushReport;
    using Witnet for Witnet.DataPullReport;
    using Witnet for Witnet.QuerySLA;
    
    using WitnetCBOR for WitnetCBOR.CBOR;

    bytes32 internal constant _WIT_ORACLE_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint256 nonce;
        mapping (Witnet.QueryId => Witnet.Query) queries;
        mapping (address => bool) reporters;
        mapping (address => mapping (Witnet.QueryCapability => Committee)) committees;
        mapping (address => Escrowable.Escrow) escrows;
        mapping (uint256 => Witnet.Beacon) beacons;
        uint256 lastKnownBeaconIndex;
    }

    struct Committee {
        bytes32 hash;
        Witnet.QueryCapabilityMember[] members;
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

    function hashify(Witnet.QuerySLA memory querySLA, address evmRequester) internal view returns (bytes32) {
        return (
            Witnet.QueryCapability.unwrap(querySLA.witCapability) == 0
                ? querySLA.hashify()
                : keccak256(abi.encode(
                    querySLA.hashify(),
                    data().committees[evmRequester][querySLA.witCapability].hash
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

    function settle(Committee storage self, Witnet.QueryCapabilityMember[] calldata members) internal returns (bytes32 hash) {
        if (members.length > 0) {
            hash = keccak256(abi.encodePacked(members));
            self.hash = hash;
            self.members = members;
        } else {
            delete self.members;
            self.hash = bytes32(0);
        }
    }


    /// =======================================================================
    /// --- Escrowable --------------------------------------------------------

    function burn(address from, uint256 value) public {
        require(
            data().escrows[from].balance >= value,
            "Escrowable: insufficient balance"
        );
        data().escrows[from].balance -= value;
        emit Escrowable.Burnt(from, value);
    }
    
    function deposit(address to, uint256 value) public {
        data().escrows[to].balance += value;
        emit Payable.Received(to, value);
    }

    function stake(address from, uint256 value) public {
        Escrowable.Escrow storage __escrow = data().escrows[from];
        require(
            __escrow.balance >= value,
            "Escrowable: insufficient balance"
        );
        __escrow.balance -= value;
        __escrow.collateral += value;
        emit Escrowable.Staked(from, value);
    }

    function slash(address from, address to, uint256 value) public {
        Escrowable.Escrow storage __escrowFrom = data().escrows[from];
        Escrowable.Escrow storage __escrowTo = data().escrows[to];
        require(
            __escrowFrom.collateral >= value,
            "Escrowable: insufficient collateral"
        );
        __escrowTo.balance += value;
        __escrowFrom.collateral -= value;
        emit Escrowable.Slashed(from, value);
        emit Payable.Received(to, value);
    }

    function unstake(address from, uint256 value) public {
        Escrowable.Escrow storage __escrow = data().escrows[from];
        require(
            __escrow.collateral >= value,
            "Escrowable: insufficient collateral"
        );
        __escrow.collateral -= value;
        __escrow.balance += value;
        emit Escrowable.Unstaked(from, value);
    }

    function withdraw(address from) public returns (uint256 _withdrawn) {
        Escrowable.Escrow storage __escrow = data().escrows[from];
        _withdrawn = __escrow.balance;
        __escrow.balance = 0;
        emit Escrowable.Withdrawn(from, _withdrawn);
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

    function deleteQuery(Witnet.QueryId queryId) public returns (Witnet.QueryReward _evmPayback) {
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
    
    function deleteQueryTrustlessly(
            Witnet.QueryId queryId, 
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        )
        public returns (Witnet.QueryReward _evmPayback)
    {
        Witnet.Query storage __query = seekQuery(queryId);
        require(
            msg.sender == __query.request.requester,
            "not the requester"
        );
        _evmPayback = __query.reward;
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(queryId, evmQueryAwaitingBlocks);
        // TODO: properly handle QueryStatus.Disputed .....
        // TODO: should pending reward be transferred to requester ??
        if (_queryStatus == Witnet.QueryStatus.Expired) {
            if (Witnet.QueryReward.unwrap(_evmPayback) > 0) {
                if (__query.response.disputer != address(0)) {
                    // transfer reporter's stake to the disputer
                    slash(
                        __query.response.reporter,
                        __query.response.disputer,
                        evmQueryReportingStake
                    );
                    // transfer back disputer's stake
                    unstake(
                        __query.response.disputer,
                        evmQueryReportingStake
                    );
                }
            }
        
        } else if (_queryStatus != Witnet.QueryStatus.Finalized) {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                toString(_queryStatus)
            )));
        }

        // completely delete query metadata from storage:
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

    function getQueryStatusTrustlessly(
            Witnet.QueryId queryId,
            uint256 evmQueryAwaitingBlocks
        )
        public view returns (Witnet.QueryStatus)
    {
        Witnet.Query storage __query = seekQuery(queryId);
        if (__query.response.resultTimestamp != 0) {
            if (block.number >= Witnet.BlockNumber.unwrap(__query.checkpoint)) {
                if (__query.response.disputer != address(0)) {
                    return Witnet.QueryStatus.Disputed;

                } else {
                    return Witnet.QueryStatus.Finalized;
                }
            } else {
                return Witnet.QueryStatus.Reported;
            }
        } else {
            uint256 _checkpoint = Witnet.BlockNumber.unwrap(__query.checkpoint);
            if (_checkpoint == 0) {
                return Witnet.QueryStatus.Unknown;
            
            } else if (block.number > _checkpoint + evmQueryAwaitingBlocks * 2) {
                return Witnet.QueryStatus.Expired;

            } else if (block.number > _checkpoint + evmQueryAwaitingBlocks) {
                return Witnet.QueryStatus.Delayed;
            
            } else {
                return Witnet.QueryStatus.Posted;
            }
        }
    }

    function getQueryResult(Witnet.QueryId queryId) public view returns (Witnet.DataResult memory _result) {
        Witnet.QueryStatus _queryStatus = getQueryStatus(queryId);
        return _getQueryResult(queryId, _queryStatus);
    }

    function getQueryResultTrustlessly(
            Witnet.QueryId queryId,
            uint256 evmQueryAwaitingBlocks
        ) 
        public view 
        returns (Witnet.DataResult memory _result)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
            queryId,
            evmQueryAwaitingBlocks
        );
        return _getQueryResult(queryId, _queryStatus);
    }

    function _getQueryResult(Witnet.QueryId queryId, Witnet.QueryStatus queryStatus)
        private view
        returns (Witnet.DataResult memory)
    {
        return intoDataResult(seekQueryResponse(queryId), queryStatus);
    }

    function intoDataResult(Witnet.QueryResponse memory queryResponse, Witnet.QueryStatus queryStatus)
        public pure
        returns (Witnet.DataResult memory _result)
    {
        _result.drTxHash = Witnet.TransactionHash.wrap(queryResponse.resultDrTxHash);
        _result.timestamp = Witnet.ResultTimestamp.wrap(queryResponse.resultTimestamp);
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

    function getQueryResponseStatusTrustlessly(
            Witnet.QueryId queryId,
            uint256 evmQueryAwaitingBlocks
        )
        public view returns (IWitOracleLegacy.QueryResponseStatus)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
            queryId,
            evmQueryAwaitingBlocks
        );
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            bytes storage __cborValues = seekQueryResponse(queryId).resultCborBytes;
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
        } else if (_queryStatus == Witnet.QueryStatus.Reported) {
            return IWitOracleLegacy.QueryResponseStatus.Finalizing;
        
        } else if (
            _queryStatus == Witnet.QueryStatus.Posted
                || _queryStatus == Witnet.QueryStatus.Delayed
        ) {
            return IWitOracleLegacy.QueryResponseStatus.Awaiting;
        
        } else if (
            _queryStatus == Witnet.QueryStatus.Expired
                || _queryStatus == Witnet.QueryStatus.Disputed
        ) {
            return IWitOracleLegacy.QueryResponseStatus.Expired;
        
        } else {
            return IWitOracleLegacy.QueryResponseStatus.Void;
        }
    }


    /// =======================================================================
    /// --- IWitOracleBlocks --------------------------------------------------

    function getLastKnownBeacon() internal view returns (Witnet.Beacon storage) {
        return data().beacons[data().lastKnownBeaconIndex];
    }

    function getLastKnownBeaconIndex() internal view returns (uint256) {
        return data().lastKnownBeaconIndex;
    }

    function rollupBeacons(Witnet.FastForward[] calldata rollup) 
        public returns (Witnet.Beacon memory head)
    {
        require(
            data().beacons[rollup[0].beacon.index].equals(rollup[0].beacon),
            "fast-forwarding from unmatching beacon"
        );
        head = _verifyFastForwards(rollup);
        data().beacons[head.index] = head;
        data().lastKnownBeaconIndex = head.index;
        emit IWitOracleBlocks.Rollup(head);
    }

    function seekBeacon(uint256 _index) internal view returns (Witnet.Beacon storage) {
        return data().beacons[_index];
    }


    /// ================================================================================
    /// --- IWitOracleTrustableReporter ------------------------------------------------

    function extractWitnetDataRequests(
            WitOracleRadonRegistry registry, 
            uint256[] calldata queryIds
        )
        public view
        returns (bytes[] memory bytecodes)
    {
        bytecodes = new bytes[](queryIds.length);
        for (uint _ix = 0; _ix < queryIds.length; _ix ++) {
            Witnet.Query storage __query = seekQuery(Witnet.QueryId.wrap(queryIds[_ix]));
            bytecodes[_ix] = (__query.request.radonRadHash != bytes32(0)
                ? registry.bytecodeOf(__query.request.radonRadHash, __query.slaParams)
                : registry.bytecodeOf(__query.request.radonBytecode, __query.slaParams)
            );
        }
    }

    function reportResult(
            address evmReporter,
            uint256 evmGasPrice,
            uint64  evmFinalityBlock,
            uint256 queryId,
            uint32  witDrResultTimestamp,
            bytes32 witDrTxHash,
            bytes calldata witDrResultCborBytes
        )
        public returns (uint256 evmReward)
    {
        // read requester address and whether a callback was requested:
        Witnet.Query storage __query = seekQuery(Witnet.QueryId.wrap(queryId));

        // read query EVM reward:
        evmReward = Witnet.QueryReward.unwrap(__query.reward);

        // set EVM reward right now as to avoid re-entrancy attacks:
        __query.reward = Witnet.QueryReward.wrap(0);

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
            uint32  witDrResultTimestamp,
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
            uint32  witDrResultTimestamp,
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
    /// --- IWitOracleTrustlessReporter ---------------------------------------

    function extractDataRequest(
            WitOracleRadonRegistry registry,
            Witnet.QueryId queryId
        )
        public view
        returns (IWitOracleTrustlessReporter.DataRequest memory)
    {
        Witnet.Query storage __query = seekQuery(queryId);
        return IWitOracleTrustlessReporter.DataRequest({
            queryId: queryId,
            queryHash: __query.hash,
            queryReward: __query.reward,
            radonBytecode: (__query.request.radonRadHash != bytes32(0)
                ? registry.bytecodeOf(__query.request.radonRadHash)
                : __query.request.radonBytecode
            ),
            radonSLA: IWitOracleTrustlessReporter.RadonSLAv21({
                params: __query.slaParams,
                members: data()
                    .committees
                        [__query.request.requester]
                        [__query.slaParams.witCapability]
                    .members
            })
        });
    }

    function claimQueryReward(
            Witnet.QueryId queryId,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        ) 
        public returns (uint256 _evmReward)
    {
        Witnet.Query storage __query = seekQuery(queryId);
        
        _evmReward = Witnet.QueryReward.unwrap(__query.reward);
        __query.reward = Witnet.QueryReward.wrap(0);

        // revert if already claimed:
        require(
            _evmReward > 0,
            "already claimed"
        );

        // deposit query's reward into the caller's balance (if proven to be legitimate):
        deposit(
            msg.sender,
            _evmReward
        );

        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
            queryId, 
            evmQueryAwaitingBlocks
        );
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            // only the reporter can claim, 
            require(
                msg.sender == __query.request.requester,
                "not the requester"
            );
            // recovering also the report stake
            unstake(
                msg.sender, 
                evmQueryReportingStake
            );

        // TODO: properly handle QueryStatus.Disputed .... 
        } else if (_queryStatus == Witnet.QueryStatus.Expired) {
            if (__query.response.disputer != address(0)) {
                // only the disputer can claim,
                require(
                    msg.sender == __query.response.disputer,
                    "not the disputer"
                );
                // receiving the reporter's stake,
                slash(
                    __query.response.reporter,
                    msg.sender, 
                    evmQueryReportingStake
                );
                // and recovering the dispute stake,
                unstake(
                    msg.sender,
                    evmQueryReportingStake
                );
                // TODO: should reward be transferred back to requester ??
                _evmReward += evmQueryReportingStake;

            } else {
                // only the requester can claim,
                require(
                    msg.sender == __query.request.requester,
                    "not the requester"
                );

            }
        } else {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                toString(_queryStatus)
            )));
        }
    }

    function disputeQueryResponse(
            Witnet.QueryId queryId,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        )
        public returns (uint256 evmPotentialReward) 
    {
        require(
            getQueryStatusTrustlessly(
                queryId, 
                evmQueryAwaitingBlocks
            ) == Witnet.QueryStatus.Reported, "not in Reported status"
        );
        stake(
            msg.sender, 
            evmQueryReportingStake
        );
        Witnet.Query storage __query = seekQuery(queryId);
        __query.checkpoint = Witnet.BlockNumber.wrap(uint64(block.number + evmQueryAwaitingBlocks));
        __query.response.disputer = msg.sender;
        emit IWitOracleEvents.WitOracleQueryResponseDispute(
            Witnet.QueryId.unwrap(queryId),
            msg.sender
        );
        return (
            Witnet.QueryReward.unwrap(__query.reward)
                + evmQueryReportingStake
        );
    }

    function reportQueryResponseTrustlessly(
            Witnet.DataPullReport calldata responseReport,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        )
        public returns (uint256)
    {
        (bool _isValidReport, string memory _queryResponseReportInvalidError) = _isValidDataPullReport(
            responseReport
        );
        require(
            _isValidReport,
            _queryResponseReportInvalidError
        );
        
        address _queryReporter;
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
            responseReport.queryId,
            evmQueryAwaitingBlocks
        );
        if (_queryStatus == Witnet.QueryStatus.Posted) {
            _queryReporter = responseReport.queryRelayer();
            require(
                _queryReporter == msg.sender,
                "unauthorized query reporter"
            );
        }

        else if (_queryStatus == Witnet.QueryStatus.Delayed) {
            _queryReporter = msg.sender;
        
        } else {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                toString(_queryStatus)
            )));
        }

        // stake from caller's balance:
        stake(msg.sender, evmQueryReportingStake);

        // save query response into storage:
        return reportResult(
            _queryReporter,
            tx.gasprice,
            uint64(block.number + evmQueryAwaitingBlocks),
            Witnet.QueryId.unwrap(responseReport.queryId),
            Witnet.determineTimestampFromEpoch(responseReport.witDrResultEpoch),
            responseReport.witDrTxHash,
            responseReport.witDrResultCborBytes
        );
    }

    function rollupQueryResponseProof(
            Witnet.FastForward[] calldata witOracleRollup,
            Witnet.DataPullReport calldata responseReport,
            bytes32[] calldata ddrTalliesMerkleTrie,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        )
        public returns (uint256 evmTotalReward)
    {
        // validate query response report
        (bool _isValidReport, string memory _queryResponseReportInvalidError) = _isValidDataPullReport(
            responseReport
        );
        require(_isValidReport, _queryResponseReportInvalidError);

        // validate rollup proofs
        Witnet.Beacon memory _witOracleHead = rollupBeacons(witOracleRollup);
        require(
            _witOracleHead.index == Witnet.determineBeaconIndexFromEpoch(
                responseReport.witDrResultEpoch
            ) + 1, "misleading head beacon"
        );

        // validate merkle proof
        require(
            _witOracleHead.ddrTalliesMerkleRoot == Witnet.merkleRoot(
                ddrTalliesMerkleTrie, 
                responseReport.tallyHash()
            ), "invalid merkle proof"
        );

        Witnet.Query storage __query = seekQuery(responseReport.queryId);
        // process query response report depending on query's current status ...
        {    
            Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
                responseReport.queryId,
                evmQueryAwaitingBlocks
            );
            if (_queryStatus == Witnet.QueryStatus.Reported) {                
                // check that proven report actually differs from what was formerly reported
                require(
                    keccak256(abi.encode(
                        responseReport.witDrTxHash, 
                        responseReport.witDrResultEpoch,
                        responseReport.witDrResultCborBytes
                    )) != keccak256(abi.encode(
                        __query.response.resultDrTxHash,
                        Witnet.determineEpochFromTimestamp(__query.response.resultTimestamp),
                        __query.response.resultCborBytes
                    )),
                    "proving no fake report"
                );

                // transfer fake reporter's stake into caller's balance:
                slash(
                    __query.response.reporter,
                    msg.sender,
                    evmQueryReportingStake
                );

                // transfer query's reward into caller's balance
                deposit(msg.sender, Witnet.QueryReward.unwrap(__query.reward));

                // update query's response data into storage:
                __query.response.reporter = msg.sender;
                __query.response.resultCborBytes = responseReport.witDrResultCborBytes;
                __query.response.resultDrTxHash = responseReport.witDrTxHash;
                __query.response.resultTimestamp = Witnet.determineTimestampFromEpoch(responseReport.witDrResultEpoch);
        
            } else if (_queryStatus == Witnet.QueryStatus.Disputed) {
                // check that proven report actually matches what was formerly reported
                require(
                    keccak256(abi.encode(
                        responseReport.witDrTxHash, 
                        responseReport.witDrResultEpoch,
                        responseReport.witDrResultCborBytes
                    )) == keccak256(abi.encode(
                        __query.response.resultDrTxHash,
                        Witnet.determineEpochFromTimestamp(__query.response.resultTimestamp),
                        __query.response.resultCborBytes
                    )),
                    "proving disputed fake report"
                );

                // transfer fake disputer's stake into reporter's balance:
                slash(
                    __query.response.disputer,
                    __query.response.reporter,
                    evmQueryReportingStake
                );

                // transfer query's reward into reporter's balance:
                deposit(__query.response.reporter, Witnet.QueryReward.unwrap(__query.reward));
                
                // clear query's disputer
                __query.response.disputer = address(0);

            } else {
                revert(string(abi.encodePacked(
                    "invalid query status: ",
                    toString(_queryStatus)
                )));
            }
            
            // finalize query:
            evmTotalReward = Witnet.QueryReward.unwrap(__query.reward) + evmQueryReportingStake;
            __query.reward = Witnet.QueryReward.wrap(0); // no claimQueryReward(.) will be required (nor accepted whatsoever)
            __query.checkpoint = Witnet.BlockNumber.wrap(uint64(block.number)); // set query status to Finalized
        }
    }

    function rollupDataPushReport(
            Witnet.DataPushReport calldata report,
            Witnet.FastForward[] calldata rollup,
            bytes32[] calldata droMerkleTrie
        )
        public returns (Witnet.DataResult memory)
    {
        // validate query report
        require(
            report.witDrRadHash != bytes32(0)
                && report.witDrResultCborBytes.length > 0
                && report.witDrResultEpoch > 0
                && report.witDrTxHash != bytes32(0)
                && report.witDrSLA.isValid()
            , "invalid query report"
        );

        // validate rollup proofs
        Witnet.Beacon memory _witOracleHead = rollupBeacons(rollup);
        require(
            _witOracleHead.index == Witnet.determineBeaconIndexFromEpoch(
                report.witDrResultEpoch
            ) + 1, "misleading head beacon"
        );

        // validate merkle proof
        require(
            _witOracleHead.droTalliesMerkleRoot == Witnet.merkleRoot(
                droMerkleTrie, 
                report.tallyHash()
            ), "invalid merkle proof"
        );

        return intoDataResult(
            Witnet.QueryResponse({
                reporter: address(0), disputer: address(0), _0: 0,
                resultCborBytes: report.witDrResultCborBytes,
                resultDrTxHash: report.witDrTxHash,
                resultTimestamp: Witnet.determineTimestampFromEpoch(report.witDrResultEpoch)
            }),
            Witnet.QueryStatus.Finalized
        );
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

    function toString(Witnet.QueryStatus _status) public pure returns (string memory) {
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
    /// --- Private library methods -------------------------------------------

    function _isValidDataPullReport(Witnet.DataPullReport calldata report)
        private view
        returns (bool, string memory)
    {
        if (
            Witnet.QueryHash.unwrap(report.queryHash)
                != Witnet.QueryHash.unwrap(seekQuery(report.queryId).hash)
        ) {
            return (false, "invalid query hash");
        
        } else if (report.witDrResultEpoch == 0) {
            return (false, "invalid result epoch");
        
        } else if (report.witDrResultCborBytes.length == 0) {
            return (false, "invalid empty result");
        
        } else {
            return (true, new string(0));
        
        }
    }

    function _verifyFastForwards(Witnet.FastForward[] calldata ff)
        private pure 
        returns (Witnet.Beacon calldata)
    {
        for (uint _ix = 1; _ix < ff.length; _ix ++) {
            require(
                ff[_ix].beacon.prevIndex == ff[_ix - 1].beacon.index
                    && ff[_ix].beacon.prevRoot == ff[_ix - 1].beacon.root(),
                string(abi.encodePacked(
                    "mismatching beacons on fast-forward step #",
                    Witnet.toString(_ix)
                ))
            );
            require(
                ff[_ix].committeeMissingPubkeys.length <= (
                    Witnet.WIT_2_FAST_FORWARD_COMMITTEE_SIZE / 3
                ), string(abi.encodePacked(
                    "too many missing pubkeys on fast-forward step #",
                    Witnet.toString(_ix)
                ))
            );
            // TODO:
            // uint256[4] memory _committeePubkey = ff[_ix - 1].beacon.nextCommitteePubkey;
            // for (uint _mx = 0; _mx < ff[_ix].committeeMissingPubKeys.length; _mx ++) {
            //     require(
            //         0 < (
            //             ff[_ix].committeeMissingPubkey[_mx][0]
            //                 + ff[_ix].committeeMissingPubkey[_mx][1]
            //                 + ff[_ix].committeeMissingPubkey[_mx][2]
            //                 + ff[_ix].committeeMissingPubkey[_mx][3]

            //         ), string(abi.encodePacked(
            //             "null missing pubkey on fast-forward step #",
            //             Witnet.toString(_ix),
            //             " index #",
            //             Witnet.toString(_mx)
            //         ))
            //     );
            //     _committeePubkey -= ff[_ix].committeeMissingPubkey[_mx];
            // }
            // require(
            //     _verifySignature(
            //         ff[_ix].beacon.committeeSignature,
            //         _committeePubkey,
            //         ff[_ix].beacon.root()

            //     ), string(abi.encodedPacked(
            //         "invalid signature on fast-forward step #",
            //         Witnet.toString(_ix)
            //     ))
            // );
        }
        return ff[ff.length - 1].beacon;
    }
}
