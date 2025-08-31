// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleDataLib.sol";
import "../interfaces/IWitOracleTrustless.sol";
import "../libs/Witnet.sol";
import "../patterns/Escrowable.sol";


/// @title Trustless Witnet Request Board data library extension
/// @author The Witnet Foundation.
library WitOracleTrustlessDataLib {  

    using Witnet for Witnet.Beacon;
    using Witnet for Witnet.BlockNumber;
    using Witnet for Witnet.DataPullReport;
    using Witnet for Witnet.DataPushReport;
    using Witnet for Witnet.QuerySLA;
    using Witnet for Witnet.Timestamp;

    bytes32 internal constant _WIT_ORACLE_BLOCKS_SLOTHASH =
        /* keccak256("io.witnet.boards.blocks") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint256 lastKnownBeaconIndex;
        mapping (uint256 => Witnet.Beacon) beacons;
        mapping (address => Escrowable.Escrow) escrows;
    }
    
    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function data() internal pure returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WIT_ORACLE_BLOCKS_SLOTHASH
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
    /// --- IWitOracleTrustless --------------------------------------------------

    function getLastKnownBeacon() internal view returns (Witnet.Beacon storage) {
        return data().beacons[data().lastKnownBeaconIndex];
    }

    function getLastKnownBeaconIndex() internal view returns (uint256) {
        return data().lastKnownBeaconIndex;
    }

    function rollupBeacons(Witnet.FastForward[] calldata rollup) 
        public 
        returns (Witnet.Beacon memory head)
    {
        head = verifyBeacons(rollup);
        data().beacons[head.index] = head;
        data().lastKnownBeaconIndex = head.index;
        emit IWitOracleTrustless.Rollup(head);
    }

    function verifyBeacons(Witnet.FastForward[] calldata rollup)
        public view
        returns (Witnet.Beacon memory head)
    {
        require(
            data().beacons[rollup[0].beacon.index].equals(rollup[0].beacon),
            "fast-forwarding from unmatching beacon"
        );
        return _verifyFastForwards(rollup);
    }

    function seekBeacon(uint256 _index) internal view returns (Witnet.Beacon storage) {
        return data().beacons[_index];
    }


    /// =======================================================================
    /// --- IWitOracle --------------------------------------------------------

    function deleteQueryTrustlessly(
            uint256 queryId,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        )
        public returns (Witnet.QueryEvmReward _evmPayback)
    {
        Witnet.Query storage self = WitOracleDataLib.seekQuery(queryId);
        require(
            msg.sender == self.request.requester,
            "not the requester"
        );
        _evmPayback = self.reward;
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(self, evmQueryAwaitingBlocks);
        // TODO: properly handle QueryStatus.Disputed .....
        // TODO: should pending reward be transferred to requester ??
        if (_queryStatus == Witnet.QueryStatus.Expired) {
            if (Witnet.QueryEvmReward.unwrap(_evmPayback) > 0) {
                if (self.response.disputer != address(0)) {
                    // transfer reporter's stake to the disputer
                    slash(
                        self.response.reporter,
                        self.response.disputer,
                        evmQueryReportingStake
                    );
                    // transfer back disputer's stake
                    unstake(
                        self.response.disputer,
                        evmQueryReportingStake
                    );
                }
            }
        
        } else if (_queryStatus != Witnet.QueryStatus.Finalized) {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                WitOracleDataLib.intoString(_queryStatus)
            )));
        }

        // completely delete query metadata from storage:
        delete WitOracleDataLib.data().queries[queryId];
    }

    function getQueryResponseStatusTrustlessly(
            Witnet.Query storage self,
            uint256 evmQueryAwaitingBlocks
        )
        public view returns (IWitOracleLegacy.QueryResponseStatus)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
            self,
            evmQueryAwaitingBlocks
        );
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            bytes storage __cborValues = self.response.resultCborBytes;
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

    function getQueryResultTrustlessly(
            Witnet.Query storage self,
            uint256 evmQueryAwaitingBlocks
        ) 
        public view 
        returns (Witnet.DataResult memory _result)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
            self,
            evmQueryAwaitingBlocks
        );
        return _getQueryResult(self, _queryStatus);
    }

    function getQueryStatusTrustlessly(
            Witnet.Query storage self,
            uint256 evmQueryAwaitingBlocks
        )
        public view returns (Witnet.QueryStatus)
    {
        if (!self.response.resultTimestamp.isZero()) {
            if (block.number >= Witnet.BlockNumber.unwrap(self.checkpoint)) {
                if (self.response.disputer != address(0)) {
                    return Witnet.QueryStatus.Disputed;

                } else {
                    return Witnet.QueryStatus.Finalized;
                }
            } else {
                return Witnet.QueryStatus.Reported;
            }
        } else {
            uint256 _checkpoint = Witnet.BlockNumber.unwrap(self.checkpoint);
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


    /// =======================================================================
    /// --- IWitOracleQueriableTrustlessReporter ---------------------------------------

    function claimQueryReward(
            uint256 queryId,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        ) 
        public returns (uint256 _evmReward)
    {    
        Witnet.Query storage self = WitOracleDataLib.seekQuery(queryId);
        
        _evmReward = Witnet.QueryEvmReward.unwrap(self.reward);
        self.reward = Witnet.QueryEvmReward.wrap(0);

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
            self,
            evmQueryAwaitingBlocks
        );
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            // only the reporter can claim, 
            require(
                msg.sender == self.request.requester,
                "not the requester"
            );
            // recovering also the report stake
            unstake(
                msg.sender, 
                evmQueryReportingStake
            );

        // TODO: properly handle QueryStatus.Disputed .... 
        } else if (_queryStatus == Witnet.QueryStatus.Expired) {
            if (self.response.disputer != address(0)) {
                // only the disputer can claim,
                require(
                    msg.sender == self.response.disputer,
                    "not the disputer"
                );
                // receiving the reporter's stake,
                slash(
                    self.response.reporter,
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
                    msg.sender == self.request.requester,
                    "not the requester"
                );

            }
        } else {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                WitOracleDataLib.intoString(_queryStatus)
            )));
        }
    }

    function disputeQueryResponse(
            uint256 queryId,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        )
        public returns (uint256 evmPotentialReward) 
    {
        Witnet.Query storage self = WitOracleDataLib.seekQuery(queryId);
        require(
            getQueryStatusTrustlessly(
                self,
                evmQueryAwaitingBlocks
            ) == Witnet.QueryStatus.Reported, "not in Reported status"
        );
        stake(
            msg.sender, 
            evmQueryReportingStake
        );
        self.checkpoint = Witnet.BlockNumber.wrap(uint64(block.number + evmQueryAwaitingBlocks));
        self.response.disputer = msg.sender;
        emit IWitOracleQueriableEvents.WitOracleQueryReportDispute(
            Witnet.QueryId.wrap(uint64(queryId)),
            msg.sender
        );
        return (
            Witnet.QueryEvmReward.unwrap(self.reward)
                + evmQueryReportingStake
        );
    }

    function reportQueryResponseTrustlessly(
            Witnet.DataPullReport calldata responseReport,
            uint256 evmQueryAwaitingBlocks,
            uint256 evmQueryReportingStake
        )
        public returns (
            address _evmReporter,
            uint256 _evmGasPrice,
            uint64  _evmFinalityBlock,
            Witnet.QueryId _queryId,
            Witnet.Timestamp _witDrTxTimestamp,
            Witnet.TransactionHash _witDrTxHash,
            bytes memory _witResultCborBytes
        )
    {
        Witnet.Query storage self = WitOracleDataLib.seekQuery(Witnet.QueryId.unwrap(responseReport.queryId));
        (bool _isValidReport, string memory _queryResponseReportInvalidError) = _isValidDataPullReport(
            self,
            responseReport
        );
        require(
            _isValidReport,
            _queryResponseReportInvalidError
        );
        
        Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(self, evmQueryAwaitingBlocks);
        if (_queryStatus == Witnet.QueryStatus.Posted) {
            _evmReporter = responseReport.queryRelayer();
            require(
                _evmReporter == msg.sender,
                "unauthorized query reporter"
            );
        }

        else if (_queryStatus == Witnet.QueryStatus.Delayed) {
            _evmReporter = msg.sender;
        
        } else {
            revert(string(abi.encodePacked(
                "invalid query status: ",
                WitOracleDataLib.intoString(_queryStatus)
            )));
        }

        // stake from caller's balance:
        stake(msg.sender, evmQueryReportingStake);

        // save query response into storage:
        _evmGasPrice = tx.gasprice;
        _evmFinalityBlock = uint64(block.number + evmQueryAwaitingBlocks);
        _queryId = responseReport.queryId;
        _witDrTxTimestamp = Witnet.determineTimestampFromEpoch(responseReport.witDrResultEpoch);
        _witDrTxHash = responseReport.witDrTxHash;
        _witResultCborBytes = responseReport.witDrResultCborBytes;
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
        Witnet.Query storage self = WitOracleDataLib.seekQuery(Witnet.QueryId.unwrap(responseReport.queryId));
        // validate query response report
        (bool _isValidReport, string memory _queryResponseReportInvalidError) = _isValidDataPullReport(
            self,
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

        // process query response report depending on query's current status ...
        {    
            Witnet.QueryStatus _queryStatus = getQueryStatusTrustlessly(
                self,
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
                        self.response.resultDrTxHash,
                        Witnet.determineEpochFromTimestamp(self.response.resultTimestamp),
                        self.response.resultCborBytes
                    )),
                    "proving no fake report"
                );

                // transfer fake reporter's stake into caller's balance:
                slash(
                    self.response.reporter,
                    msg.sender,
                    evmQueryReportingStake
                );

                // transfer query's reward into caller's balance
                deposit(msg.sender, Witnet.QueryEvmReward.unwrap(self.reward));

                // update query's response data into storage:
                self.response.reporter = msg.sender;
                self.response.resultCborBytes = responseReport.witDrResultCborBytes;
                self.response.resultDrTxHash = responseReport.witDrTxHash;
                self.response.resultTimestamp = Witnet.determineTimestampFromEpoch(responseReport.witDrResultEpoch);
        
            } else if (_queryStatus == Witnet.QueryStatus.Disputed) {
                // check that proven report actually matches what was formerly reported
                require(
                    keccak256(abi.encode(
                        responseReport.witDrTxHash, 
                        responseReport.witDrResultEpoch,
                        responseReport.witDrResultCborBytes
                    )) == keccak256(abi.encode(
                        self.response.resultDrTxHash,
                        Witnet.determineEpochFromTimestamp(self.response.resultTimestamp),
                        self.response.resultCborBytes
                    )),
                    "proving disputed fake report"
                );

                // transfer fake disputer's stake into reporter's balance:
                slash(
                    self.response.disputer,
                    self.response.reporter,
                    evmQueryReportingStake
                );

                // transfer query's reward into reporter's balance:
                deposit(self.response.reporter, Witnet.QueryEvmReward.unwrap(self.reward));
                
                // clear query's disputer
                self.response.disputer = address(0);

            } else {
                revert(string(abi.encodePacked(
                    "invalid query status: ",
                    WitOracleDataLib.intoString(_queryStatus)
                )));
            }
            
            // finalize query:
            evmTotalReward = Witnet.QueryEvmReward.unwrap(self.reward) + evmQueryReportingStake;
            self.reward = Witnet.QueryEvmReward.wrap(0); // no claimQueryReward(.) will be required (nor accepted whatsoever)
            self.checkpoint = Witnet.BlockNumber.wrap(uint64(block.number)); // set query status to Finalized
        }
    }

    function parseDataPushReport(
            Witnet.DataPushReport calldata report,
            Witnet.FastForward[] calldata rollup,
            bytes32[] calldata droMerkleTrie
        )
        public view returns (Witnet.DataResult memory)
    {
        // validate query report
        require(
            Witnet.RadonHash.unwrap(report.queryRadHash) != bytes32(0)
                && report.resultCborBytes.length > 0
                && !report.resultTimestamp.isZero()
                && Witnet.TransactionHash.unwrap(report.witDrTxHash) != bytes32(0)
                && report.queryParams.isValid()
            , "invalid query report"
        );

        // validate rollup proofs
        Witnet.Beacon memory _witOracleHead = verifyBeacons(rollup);
        require(
            _witOracleHead.index >= Witnet.determineBeaconIndexFromTimestamp(report.resultTimestamp) + 1, 
            "misleading head beacon"
        );

        // validate merkle proof
        require(
            _witOracleHead.droTalliesMerkleRoot == Witnet.merkleRoot(
                droMerkleTrie, 
                report.digest()
            ), "invalid merkle proof"
        );

        return WitOracleDataLib.intoDataResult(
            Witnet.QueryResponse({
                reporter: address(0), disputer: address(0), _0: 0,
                resultCborBytes: report.resultCborBytes,
                resultDrTxHash: report.witDrTxHash,
                resultTimestamp: report.resultTimestamp
            }),
            Witnet.QueryStatus.Finalized,
            uint64(block.number)
        );
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
            Witnet.RadonHash.unwrap(report.queryRadHash) != bytes32(0)
                && report.resultCborBytes.length > 0
                && !report.resultTimestamp.isZero()
                && Witnet.TransactionHash.unwrap(report.witDrTxHash) != bytes32(0)
                && report.queryParams.isValid()
            , "invalid query report"
        );

        // validate rollup proofs
        Witnet.Beacon memory _witOracleHead = rollupBeacons(rollup);
        require(
            _witOracleHead.index >= Witnet.determineBeaconIndexFromTimestamp(report.resultTimestamp) + 1, 
            "misleading head beacon"
        );

        // validate merkle proof
        require(
            _witOracleHead.droTalliesMerkleRoot == Witnet.merkleRoot(
                droMerkleTrie, 
                report.digest()
            ), "invalid merkle proof"
        );

        return WitOracleDataLib.intoDataResult(
            Witnet.QueryResponse({
                reporter: address(0), disputer: address(0), _0: 0,
                resultCborBytes: report.resultCborBytes,
                resultDrTxHash: report.witDrTxHash,
                resultTimestamp: report.resultTimestamp 
            }),
            Witnet.QueryStatus.Finalized,
            uint64(block.number)
        );
    }

    
    /// =======================================================================
    /// --- Private library methods -------------------------------------------

    function _getQueryResult(Witnet.Query storage self, Witnet.QueryStatus queryStatus)
        private view
        returns (Witnet.DataResult memory)
    {
        return WitOracleDataLib.intoDataResult(
            self.response, 
            queryStatus,
            Witnet.BlockNumber.unwrap(self.checkpoint)
        );
    }

    function _isValidDataPullReport(
            Witnet.Query storage self,
            Witnet.DataPullReport calldata report
        )
        private view
        returns (bool, string memory)
    {
        if (
            Witnet.QueryUUID.unwrap(report.queryHash)
                != Witnet.QueryUUID.unwrap(self.uuid)
        ) {
            return (false, "invalid query hash");
        
        } else if (report.witDrResultEpoch.isZero()) {
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
