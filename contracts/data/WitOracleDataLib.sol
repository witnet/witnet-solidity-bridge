// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../WitOracleRadonRegistry.sol";
import "../interfaces/IWitOracleAdminACLs.sol";
import "../interfaces/IWitOracleBlocks.sol";
import "../interfaces/IWitOracleConsumer.sol";
import "../interfaces/IWitOracleEvents.sol";
import "../interfaces/IWitOracleReporter.sol";
import "../libs/Witnet.sol";
import "../patterns/Escrowable.sol";

/// @title Witnet Request Board base data model library
/// @author The Witnet Foundation.
library WitOracleDataLib {  

    using Witnet for Witnet.Beacon;
    using Witnet for Witnet.QueryReport;
    using Witnet for Witnet.QueryResponseReport;
    using Witnet for Witnet.RadonSLA;
    
    using WitnetCBOR for WitnetCBOR.CBOR;

    bytes32 internal constant _WIT_ORACLE_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint256 nonce;
        mapping (uint => Witnet.Query) queries;
        mapping (address => bool) reporters;
        mapping (address => Escrowable.Escrow) escrows;
        mapping (uint256 => Witnet.Beacon) beacons;
        uint256 lastKnownBeaconIndex;
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

    function queryHashOf(Storage storage self, bytes4 channel, uint256 queryId)
        internal view returns (bytes32)
    {
        Witnet.Query storage __query = self.queries[queryId];
        return keccak256(abi.encode(
            channel,
            queryId,
            blockhash(__query.block),
            __query.request.radonRadHash != bytes32(0)
                ? __query.request.radonRadHash 
                : keccak256(bytes(__query.request.radonBytecode)),
            __query.request.radonSLA
        ));
    }

    /// Saves query response into storage.
    function saveQueryResponse(
            address evmReporter,
            uint64  evmFinalityBlock,
            uint256 queryId,
            uint32  resultTimestamp,
            bytes32 resultDrTxHash,
            bytes memory resultCborBytes
        ) internal
    {
        seekQuery(queryId).response = Witnet.QueryResponse({
            reporter: evmReporter,
            finality: evmFinalityBlock,
            resultTimestamp: resultTimestamp,
            resultDrTxHash: resultDrTxHash,
            resultCborBytes: resultCborBytes,
            disputer: address(0)
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
    
    function fetchQueryResponseTrustlessly(
            uint256 evmQueryReportingStake,
            uint256 queryId, 
            Witnet.QueryStatus queryStatus
        )
        public returns (Witnet.QueryResponse memory _queryResponse)
    {
        Witnet.Query storage __query = seekQuery(queryId);

        uint72 _evmReward = __query.request.evmReward;
        __query.request.evmReward = 0;

        if (queryStatus == Witnet.QueryStatus.Expired) {
            if (_evmReward > 0) {
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
        
        } else if (queryStatus != Witnet.QueryStatus.Finalized) {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                toString(queryStatus)
            )));
        }

        // completely delete query metadata from storage:
        _queryResponse = __query.response;
        delete data().queries[queryId];

        // transfer unused reward to requester:
        if (_evmReward > 0) {
            deposit(msg.sender, _evmReward);
        }    
    }

    function getQueryStatusTrustlessly(
            uint256 queryId,
            uint256 evmQueryAwaitingBlocks
        )
        public view returns (Witnet.QueryStatus)
    {
        Witnet.Query storage __query = seekQuery(queryId);
        if (__query.response.resultTimestamp != 0) {
            if (block.number >= __query.response.finality) {
                if (__query.response.disputer != address(0)) {
                    return Witnet.QueryStatus.Expired;

                } else {
                    return Witnet.QueryStatus.Finalized;
                }
            } else {
                if (__query.response.disputer != address(0)) {
                    return Witnet.QueryStatus.Disputed;
                    
                } else {
                    return Witnet.QueryStatus.Reported;
                }
            }
        } else if (__query.block == 0) {
            return Witnet.QueryStatus.Unknown;
        
        } else if (block.number > __query.block + evmQueryAwaitingBlocks * 2) {
            return Witnet.QueryStatus.Expired;

        } else if (block.number > __query.block + evmQueryAwaitingBlocks) {
            return Witnet.QueryStatus.Delayed;
        
        } else {
            return Witnet.QueryStatus.Posted;
        }
    }

    function getQueryResponseStatusTrustlessly(
            uint256 queryId,
            uint256 evmQueryAwaitingBlocks
        )
        public view returns (Witnet.QueryResponseStatus)
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
                    ? Witnet.QueryResponseStatus.Error 
                    : Witnet.QueryResponseStatus.Ready
                );
            
            } else {
                // the result is final but delivered to the requesting address
                return Witnet.QueryResponseStatus.Delivered;
            }
        } else if (
            _queryStatus == Witnet.QueryStatus.Posted
                || _queryStatus == Witnet.QueryStatus.Delayed
        ) {
            return Witnet.QueryResponseStatus.Awaiting;
        
        } else if (
            _queryStatus == Witnet.QueryStatus.Reported
                || _queryStatus == Witnet.QueryStatus.Disputed
        ) {
            return Witnet.QueryResponseStatus.Finalizing;
        
        } else if (_queryStatus == Witnet.QueryStatus.Expired) {
            return Witnet.QueryResponseStatus.Expired;
        
        } else {
            return Witnet.QueryResponseStatus.Void;
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


    /// =======================================================================
    /// --- IWitOracleReporter ------------------------------------------------

    function extractWitnetDataRequests(
            WitOracleRadonRegistry registry, 
            uint256[] calldata queryIds
        )
        public view
        returns (bytes[] memory bytecodes)
    {
        bytecodes = new bytes[](queryIds.length);
        for (uint _ix = 0; _ix < queryIds.length; _ix ++) {
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
    
    function reportQueryResponse(
            address evmReporter,
            uint256 evmGasPrice,
            uint64  evmFinalityBlock,
            Witnet.QueryResponseReport calldata report
        )
        public returns (uint256 evmReward)
        // todo: turn into private
    {
        // read requester address and whether a callback was requested:
        Witnet.QueryRequest storage __request = seekQueryRequest(report.queryId);
                
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
            ) = reportQueryResponseCallback(
                __request.requester,
                __request.gasCallback,
                evmFinalityBlock,
                report
            );
            if (evmCallbackSuccess) {
                // => the callback run successfully
                emit IWitOracleEvents.WitOracleQueryReponseDelivered(
                    report.queryId,
                    evmGasPrice,
                    evmCallbackActualGas
                );
            } else {
                // => the callback reverted
                emit IWitOracleEvents.WitOracleQueryResponseDeliveryFailed(
                    report.queryId,
                    evmGasPrice,
                    evmCallbackActualGas,
                    bytes(evmCallbackRevertMessage).length > 0 
                        ? evmCallbackRevertMessage
                        : "WitOracleDataLib: callback exceeded gas limit",
                    report.witDrResultCborBytes
                );
            }
            // upon delivery, successfull or not, the audit trail is saved into storage, 
            // but not the actual result which was intended to be passed over to the requester:
            saveQueryResponse(
                evmReporter,
                evmFinalityBlock,
                report.queryId, 
                Witnet.determineTimestampFromEpoch(report.witDrResultEpoch), 
                report.witDrTxHash,
                hex""
            );
        } else {
            // => no callback is involved
            emit IWitOracleEvents.WitOracleQueryResponse(
                report.queryId, 
                evmGasPrice
            );
            // write query result and audit trail data into storage 
            saveQueryResponse(
                evmReporter,
                evmFinalityBlock,
                report.queryId,
                Witnet.determineTimestampFromEpoch(report.witDrResultEpoch),
                report.witDrTxHash,
                report.witDrResultCborBytes
            );
        }
    }

    function reportQueryResponseCallback(
            address evmRequester,
            uint24  evmCallbackGasLimit,
            uint64  evmFinalityBlock,
            Witnet.QueryResponseReport calldata report
        )
        public returns (
            uint256 evmCallbackActualGas, 
            bool evmCallbackSuccess, 
            string memory evmCallbackRevertMessage
        )
        // todo: turn into private
    {
        evmCallbackActualGas = gasleft();
        if (report.witDrResultCborBytes[0] == bytes1(0xd8)) {
            WitnetCBOR.CBOR[] memory _errors = WitnetCBOR.fromBytes(report.witDrResultCborBytes).readArray();
            if (_errors.length < 2) {
                // try to report result with unknown error:
                try IWitOracleConsumer(evmRequester).reportWitOracleResultError{gas: evmCallbackGasLimit}(
                    report.queryId,
                    Witnet.determineTimestampFromEpoch(report.witDrResultEpoch),
                    report.witDrTxHash,
                    evmFinalityBlock,
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
                    report.queryId,
                    Witnet.determineEpochFromTimestamp(report.witDrResultEpoch),
                    report.witDrTxHash,
                    evmFinalityBlock,
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
                report.queryId,
                Witnet.determineTimestampFromEpoch(report.witDrResultEpoch),
                report.witDrTxHash,
                evmFinalityBlock,
                WitnetCBOR.fromBytes(report.witDrResultCborBytes)
            ) {
                evmCallbackSuccess = true;
            } catch Error(string memory err) {
                evmCallbackRevertMessage = err;
            } catch (bytes memory) {}
        }
        evmCallbackActualGas -= gasleft();
    }

    function reportQueryResponseTrustlessly(
            bytes4 channel,
            uint256 evmGasPrice,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake,
            Witnet.QueryStatus queryStatus,
            Witnet.QueryResponseReport calldata queryResponseReport
        )
        public returns (uint256)
    {
        (bool _isValidQueryResponseReport, string memory _queryResponseReportInvalidError) = isValidQueryResponseReport(
            channel, 
            queryResponseReport
        );
        require(
            _isValidQueryResponseReport,
            _queryResponseReportInvalidError
        );
        
        address _queryReporter;
        if (queryStatus == Witnet.QueryStatus.Posted) {
            _queryReporter = queryResponseReport.queryRelayer();
            require(
                _queryReporter == msg.sender,
                "unauthorized query reporter"
            );
        }

        else if (queryStatus == Witnet.QueryStatus.Delayed) {
            _queryReporter = msg.sender;
        
        } else {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                toString(queryStatus)
            )));
        }

        // stake from caller's balance:
        stake(msg.sender, evmQueryReportingStake);

        // save query response into storage:
        return reportQueryResponse(
            _queryReporter,
            evmGasPrice,
            uint64(block.number + evmQueryAwaitingBlocks),
            queryResponseReport
        );
    }


    /// =======================================================================
    /// --- IWitOracleReporterTrustless ---------------------------------------

    function claimQueryReward(
            uint256 evmQueryReportingStake,
            uint256 queryId, 
            Witnet.QueryStatus queryStatus
        ) 
        public returns (uint256 evmReward)
    {
        Witnet.Query storage __query = seekQuery(queryId);
        
        evmReward = __query.request.evmReward;
        __query.request.evmReward = 0;

        // revert if already claimed:
        require(
            evmReward > 0,
            "already claimed"
        );

        // deposit query's reward into the caller's balance (if proven to be legitimate):
        deposit(
            msg.sender,
            evmReward
        );

        if (queryStatus == Witnet.QueryStatus.Finalized) {
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

        } else if (queryStatus == Witnet.QueryStatus.Expired) {
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
                evmReward += evmQueryReportingStake;

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
                toString(queryStatus)
            )));
        }
    }

    function disputeQueryResponse(
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake,
            uint256 queryId
        )
        public returns (uint256 evmPotentialReward) 
    {
        stake(msg.sender, evmQueryReportingStake);
        Witnet.Query storage __query = seekQuery(queryId);
        __query.response.disputer = msg.sender;
        __query.response.finality = uint64(block.number + evmQueryAwaitingBlocks);
        emit IWitOracleEvents.WitOracleQueryResponseDispute(
            queryId,
            msg.sender
        );
        return (
            __query.request.evmReward
                + evmQueryReportingStake
        );
    }

    function rollupQueryResponseProof(
            bytes4  channel,
            uint256 evmQueryReportingStake,
            Witnet.QueryResponseReport calldata queryResponseReport,
            Witnet.QueryStatus queryStatus,
            Witnet.FastForward[] calldata witOracleRollup,
            bytes32[] calldata ddrTalliesMerkleTrie
        )
        public returns (uint256 evmTotalReward)
    {
        // validate query response report
        (bool _isValidQueryResponseReport, string memory _queryResponseReportInvalidError) = isValidQueryResponseReport(
            channel, 
            queryResponseReport
        );
        require(_isValidQueryResponseReport, _queryResponseReportInvalidError);

        // validate rollup proofs
        Witnet.Beacon memory _witOracleHead = rollupBeacons(witOracleRollup);
        require(
            _witOracleHead.index == Witnet.determineBeaconIndexFromEpoch(
                queryResponseReport.witDrResultEpoch
            ) + 1, "mismatching head beacon"
        );

        // validate merkle proof
        require(
            _witOracleHead.ddrTalliesMerkleRoot == Witnet.merkleRoot(
                ddrTalliesMerkleTrie, 
                queryResponseReport.tallyHash()
            ), "invalid merkle proof"
        );

        Witnet.Query storage __query = seekQuery(queryResponseReport.queryId);
        // process query response report depending on query's current status ...
        {    
            if (queryStatus == Witnet.QueryStatus.Reported) {                
                // check that proven report actually differs from what was formerly reported
                require(
                    keccak256(abi.encode(
                        queryResponseReport.witDrTxHash, 
                        queryResponseReport.witDrResultEpoch,
                        queryResponseReport.witDrResultCborBytes
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
                deposit(msg.sender, __query.request.evmReward);

                // update query's response data into storage:
                __query.response.reporter = msg.sender;
                __query.response.resultCborBytes = queryResponseReport.witDrResultCborBytes;
                __query.response.resultDrTxHash = queryResponseReport.witDrTxHash;
                __query.response.resultTimestamp = Witnet.determineTimestampFromEpoch(queryResponseReport.witDrResultEpoch);
        
            } else if (queryStatus == Witnet.QueryStatus.Disputed) {
                // check that proven report actually matches what was formerly reported
                require(
                    keccak256(abi.encode(
                        queryResponseReport.witDrTxHash, 
                        queryResponseReport.witDrResultEpoch,
                        queryResponseReport.witDrResultCborBytes
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
                deposit(__query.response.reporter, __query.request.evmReward);
                
                // clear query's disputer
                __query.response.disputer = address(0);

            } else {
                revert(string(abi.encodePacked(
                    "invalid query status: ",
                    toString(queryStatus)
                )));
            }
            
            // finalize query:
            evmTotalReward = __query.request.evmReward + evmQueryReportingStake;
            __query.request.evmReward = 0; // no claimQueryReward(.) will be required (nor accepted whatsoever)
            __query.response.finality = uint64(block.number); // set query status to Finalized
        }
    }

    function rollupQueryResultProof(
            Witnet.QueryReport calldata queryReport,
            Witnet.FastForward[] calldata witOracleRollup,
            bytes32[] calldata droTalliesMerkleTrie
        )
        public returns (Witnet.Result memory)
    {
        // validate query report
        require(
            queryReport.witDrRadHash != bytes32(0)
                && queryReport.witDrResultCborBytes.length > 0
                && queryReport.witDrResultEpoch > 0
                && queryReport.witDrTxHash != bytes32(0)
                && queryReport.witDrSLA.isValid()
            , "invalid query report"
        );

        // validate rollup proofs
        Witnet.Beacon memory _witOracleHead = rollupBeacons(witOracleRollup);
        require(
            _witOracleHead.index == Witnet.determineBeaconIndexFromEpoch(
                queryReport.witDrResultEpoch
            ) + 1, "mismatching head beacon"
        );

        // validate merkle proof
        require(
            _witOracleHead.droTalliesMerkleRoot == Witnet.merkleRoot(
                droTalliesMerkleTrie, 
                queryReport.tallyHash()
            ), "invalid merkle proof"
        );

        // deserialize result cbor bytes into Witnet.Result
        return Witnet.toWitnetResult(
            queryReport.witDrResultCborBytes
        );
    }


    /// =======================================================================
    /// --- Other public helper methods ---------------------------------------

    function isValidQueryResponseReport(bytes4 channel, Witnet.QueryResponseReport calldata report)
        public view
        // todo: turn into private
        returns (bool, string memory)
    {
        if (queryHashOf(data(), channel, report.queryId) != report.queryHash) {
            return (false, "invalid query hash");
        
        } else if (report.witDrResultEpoch == 0) {
            return (false, "invalid result epoch");
        
        } else if (report.witDrResultCborBytes.length == 0) {
            return (false, "invalid empty result");
        
        } else {
            return (true, new string(0));
        
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

    function toString(Witnet.QueryResponseStatus _status) external pure returns (string memory) {
        if (_status == Witnet.QueryResponseStatus.Awaiting) {
            return "Awaiting";
        } else if (_status == Witnet.QueryResponseStatus.Ready) {
            return "Ready";
        } else if (_status == Witnet.QueryResponseStatus.Error) {
            return "Reverted";
        } else if (_status == Witnet.QueryResponseStatus.Finalizing) {
            return "Finalizing";
        } else if (_status == Witnet.QueryResponseStatus.Delivered) {
            return "Delivered";
        } else if (_status == Witnet.QueryResponseStatus.Expired) {
            return "Expired";
        } else {
            return "Unknown";
        }
    }


    /// =======================================================================
    /// --- Private library methods -------------------------------------------

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
