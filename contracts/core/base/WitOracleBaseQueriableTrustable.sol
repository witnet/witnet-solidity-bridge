// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBaseQueriable.sol";
import "../WitnetUpgradableBase.sol";
import "../../interfaces/IWitOracleTrustableAdmin.sol";
import "../../interfaces/IWitOracleQueriable.sol";
import "../../interfaces/IWitOracleQueriableTrustableReporter.sol";
import "../../interfaces/legacy/IWitOracleLegacy.sol";

/// @title Queriable WitOracle "trustable" base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBaseQueriableTrustable
    is
        WitnetUpgradableBase,
        WitOracleBaseQueriable,
        IWitOracleTrustableAdmin,
        IWitOracleLegacy,
        IWitOracleQueriableTrustableReporter
{
    using Witnet for Witnet.DataPushReport;
    using Witnet for Witnet.QuerySLA;
    using Witnet for Witnet.Timestamp;

    /// Asserts the caller is authorized as a reporter
    modifier onlyReporters virtual {
        _require(
            WitOracleDataLib.data().reporters[msg.sender],
            "unauthorized reporter"
        ); _;
    }

    constructor(bytes32 _versionTag)
        Ownable(msg.sender)
        Payable(address(0))
        WitnetUpgradableBase(
            true, 
            _versionTag,
            "io.witnet.proxiable.board"
        )
    {} 


    // ================================================================================================================
    // --- Upgradeable ------------------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory _initData) virtual override internal {
        WitOracleDataLib.setReporters(abi.decode(_initData, (address[])));
    }


    // ================================================================================================================
    // --- IWitOracle -------------------------------------------------------------------------------------------------

    function parseDataReport(Witnet.DataPushReport calldata _report, bytes calldata _signature)
        virtual override public view
        returns (Witnet.DataResult memory _result)
    {
        (, _result) = WitOracleDataLib.parseDataReport(_report, _signature);
    }

    function pushDataReport(Witnet.DataPushReport calldata _report, bytes calldata _signature)
        virtual override external
        returns (Witnet.DataResult memory)
    {
        (address _evmSigner, Witnet.DataResult memory _result) = WitOracleDataLib.parseDataReport(_report, _signature);
        emit WitOracleReport(
            tx.origin, 
            msg.sender, 
            _evmSigner, 
            _report.witDrTxHash,
            _report.queryRadHash,
            _report.queryParams,
            _report.resultTimestamp,
            _report.resultCborBytes
        );
        return _result;
    }


    // ================================================================================================================
    // --- IWitOracleQueriable ----------------------------------------------------------------------------------------

    /// @notice Removes all query data from storage. Pays back reward on expired queries.
    /// @dev Fails if the query is not in a final status, or not called from the actual requester.
    function deleteQuery(uint256 _queryId)
        virtual override public
        returns (Witnet.QueryEvmReward)
    {
        try WitOracleDataLib.deleteQuery(
            _queryId
        
        ) returns (
            Witnet.QueryEvmReward _queryReward
        ) {
            uint256 _evmPayback = Witnet.QueryEvmReward.unwrap(_queryReward);
            if (_evmPayback > 0) {
                // transfer unused reward to requester, only if the query expired:
                __safeTransferTo(
                    payable(msg.sender),
                    _evmPayback
                );
            }
            return _queryReward;
        
        } catch Error(string memory _reason) {
            _revert(_reason);

        } catch (bytes memory) {
            _revertUnhandledException();
        }
    }

    /// Gets current status of given query.
    function getQueryStatus(uint256 _queryId) 
        virtual override
        public view
        returns (Witnet.QueryStatus)
    {
        return WitOracleDataLib.getQueryStatus(_queryId);
    }


    // ================================================================================================================
    // --- Implements IWitOracleTrustableAdmin -----------------------------------------------------------------------------

    /// Tells whether given address is included in the active reporters control list.
    /// @param _queryResponseReporter The address to be checked.
    function isReporter(address _queryResponseReporter) virtual override public view returns (bool) {
        return WitOracleDataLib.isReporter(_queryResponseReporter);
    }

    /// Adds given addresses to the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersSet` event. 
    /// @param _queryResponseReporters List of addresses to be added to the active reporters control list.
    function setReporters(address[] calldata _queryResponseReporters)
        virtual override public
        onlyOwner
    {
        WitOracleDataLib.setReporters(_queryResponseReporters);
    }

    /// Removes given addresses from the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersUnset` event. 
    /// @param _exReporters List of addresses to be added to the active reporters control list.
    function unsetReporters(address[] calldata _exReporters)
        virtual override public
        onlyOwner
    {
        WitOracleDataLib.unsetReporters(_exReporters);
    }


    /// ===============================================================================================================
    /// --- IWitOracleLegacy ------------------------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    function estimateBaseFee(uint256 _gasPrice, uint16)
        public view
        virtual override
        returns (uint256)
    {
        return estimateBaseFee(_gasPrice);
    }

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `resultMaxSize`. 
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param radHash The hash of some Witnet Data Request previously posted in the WitOracleRadonRegistry registry.
    function estimateBaseFee(uint256 gasPrice, bytes32 radHash)
        public view
        virtual override
        returns (uint256)
    {
        // Check this rad hash is actually verified:
        _require(
            registry.isVerifiedRadonRequest(Witnet.RadonHash.wrap(radHash)),
            "unknown radon hash"
        );

        // Base fee is actually invariant to max result size:
        return estimateBaseFee(gasPrice);
    }

    function extractWitnetDataRequests(uint256[] calldata queryIds) external view returns (bytes[] memory) {
        Witnet.QueryId[] memory _ids = new Witnet.QueryId[](queryIds.length);
        for (uint _ix; _ix < _ids.length; _ix ++) {
            _ids[_ix] = Witnet.QueryId.wrap(uint64(queryIds[_ix]));
        }
        return extractRadonBytecodes(_ids);
    }

    function fetchQueryResponse(uint256 queryId) virtual override external returns (bytes memory) {
        deleteQuery(queryId);
        return hex"";
    }

    function getQuery(uint256 queryId) 
        virtual override 
        external view 
        returns (IWitOracleLegacy.Query memory)
    {
        return IWitOracleLegacy.Query({
            request: getQueryRequest(queryId),
            response: getQueryResponse(queryId)
        });
    }

    function getQueryRequest(uint256 queryId)
        virtual override
        public view
        returns (IWitOracleLegacy.QueryRequest memory)
    {
        WitOracleDataLib.Query storage __query = __storage().queries[queryId];
        if (__query.request.radonBytecode.length > 65535) {
            // read from v1 layout
            return IWitOracleLegacy.QueryRequest({
                requester: address(0),
                callbackGas: 0,
                evmReward: 0,
                radonBytecode: hex"",
                radonHash: __query.request.radonHash,
                radonParams: IWitOracleLegacy.RadonSLA({
                    numWitnesses: 0,
                    witnessReward: 0
                })
            });

        } else if (__query.request._1 > 0) {
            // read from v2 layout
            return IWitOracleLegacy.QueryRequest({
                requester: __query.request.requester,
                callbackGas: __query.request.callbackGas,
                evmReward: __query.request._0,
                radonBytecode: __query.request.radonBytecode,
                radonHash: __query.request.radonHash,
                radonParams: IWitOracleLegacy.RadonSLA({
                    numWitnesses: uint8(__query.slaParams.witCommitteeSize),
                    witnessReward: __query.slaParams.witUnitaryReward
                })
            });
        } else {
            // read from v3 layout
            return IWitOracleLegacy.QueryRequest({
                requester: __query.request.requester,
                callbackGas: __query.request.callbackGas,
                evmReward: Witnet.QueryEvmReward.unwrap(__query.reward),
                radonBytecode: __query.request.radonBytecode,
                radonHash: __query.request.radonHash,
                radonParams: IWitOracleLegacy.RadonSLA({
                    numWitnesses: uint8(__query.slaParams.witCommitteeSize),
                    witnessReward: __query.slaParams.witUnitaryReward
                })
            });
        }
    }

    function getQueryResponse(uint256 queryId)
        virtual override
        public view
        returns (IWitOracleLegacy.QueryResponse memory)
    {
        WitOracleDataLib.Query storage __query = __storage().queries[queryId];
        if (__query.request.radonBytecode.length > 65535) {
            // read from v1 layout
            return IWitOracleLegacy.QueryResponse({
                reporter: address(0),
                finality: uint64(0),
                timestamp: uint32(0),
                trail: bytes32(0),
                cborBytes: new bytes(0)
            });

        } else if (__query.request._1 > 0) {
            // read from v2 layout
            return IWitOracleLegacy.QueryResponse({
                reporter: __query.response.reporter,
                finality: uint64(__query.response._0),
                timestamp: uint32(__query.response.resultTimestamp >> 32),
                trail: __query.response.resultDrTxHash,
                cborBytes: __query.response.resultCborBytes
            });

        } else {
            // read from v3 layout
            return IWitOracleLegacy.QueryResponse({
                reporter: __query.response.reporter,
                finality: Witnet.BlockNumber.unwrap(__query.checkpoint),
                timestamp: uint32(__query.response.resultTimestamp),
                trail: __query.response.resultDrTxHash,
                cborBytes: __query.response.resultCborBytes
            });
        }
    }

    function getQueryResponseStatus(uint256 queryId) 
        virtual override 
        public view 
        returns (IWitOracleLegacy.QueryResponseStatus)
    {
        return WitOracleDataLib.getQueryResponseStatus(queryId);
    }

    function getQueryResultCborBytes(uint256 queryId) virtual override external view returns (bytes memory) {
        return getQueryResponse(Witnet.QueryId.wrap(uint64(queryId))).resultCborBytes;
    }

    function getQueryResultError(uint256 queryId) virtual override external view returns (IWitOracleLegacy.ResultError memory) {
        Witnet.DataResult memory _result = getQueryResult(queryId);
        return IWitOracleLegacy.ResultError({
            code: uint8(_result.status),
            reason: WitOracleResultStatusLib.toString(abi.encode(_result))
        });
    }

    function postRequest(
            bytes32 _queryRadHash, 
            IWitOracleLegacy.RadonSLA calldata _querySLA
        )
        virtual override
        external payable
        returns (uint256)
    {
        return queryData(
            Witnet.RadonHash.wrap(_queryRadHash),
            Witnet.QuerySLA({
                witResultMaxSize: 32,
                witCommitteeSize: _querySLA.numWitnesses,
                witUnitaryReward: _querySLA.witnessReward
            })
        );
    }

    function postRequestWithCallback(
            bytes32 _queryRadHash,
            IWitOracleLegacy.RadonSLA calldata _querySLA,
            uint24 _queryCallbackGas
        )
        virtual override
        external payable
        returns (uint256)
    {
        return queryDataWithCallback(
            Witnet.RadonHash.wrap(_queryRadHash),
            Witnet.QuerySLA({
                witResultMaxSize: 32,
                witCommitteeSize: _querySLA.numWitnesses,
                witUnitaryReward: _querySLA.witnessReward
            }),
            Witnet.QueryCallback({
                consumer: msg.sender,
                gasLimit: _queryCallbackGas
            })
        );
    }

    function reportResult(
            uint256 queryId,
            uint32 resultTimestamp,
            bytes32 drTxHash,
            bytes calldata resultCborBytes
        )
        external override
        onlyReporters
        returns (uint256)
    {
        return reportResult(
            Witnet.QueryId.wrap(uint64(queryId)),
            Witnet.Timestamp.wrap(resultTimestamp),
            Witnet.TransactionHash.wrap(drTxHash),
            resultCborBytes
        );
    }

    function reportResult(
            uint256 queryId,
            bytes32 drTxHash,
            bytes calldata resultCborBytes
        )
        external override
        onlyReporters
        returns (uint256)
    {
        return reportResult(
            Witnet.QueryId.wrap(uint64(queryId)),
            Witnet.TransactionHash.wrap(drTxHash),
            resultCborBytes
        );
    }

    function reportResultBatch(BatchResultLegacy[] calldata results)
        external override
        onlyReporters
        returns (uint256 _batchReward)
    {
        IWitOracleQueriableTrustableReporter.BatchResult[] memory _results = new IWitOracleQueriableTrustableReporter.BatchResult[](results.length);
        for (uint _ix = 0; _ix < results.length; _ix ++) {
            _results[_ix] = BatchResult({
                queryId: Witnet.QueryId.wrap(uint64(results[_ix].queryId)),
                resultTimestamp: Witnet.Timestamp.wrap(results[_ix].resultTimestamp),
                drTxHash: Witnet.TransactionHash.wrap(results[_ix].drTxHash),
                resultCborBytes: results[_ix].resultCborBytes
            });
        }
        return reportResultBatch(_results);
    }



    // =========================================================================================================================
    // --- Implements IWitOracleQueriableTrustableReporter ------------------------------------------------------------------------------

    /// @notice Estimates the actual earnings (or loss), in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    function estimateReportEarnings(
            uint256[] calldata _queryIds, 
            bytes calldata,
            uint256 _evmGasPrice,
            uint256 _evmWitPrice
        )
        external view
        virtual override
        returns (uint256 _revenues, uint256 _expenses)
    {
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            uint256 _queryId = _queryIds[_ix];
            if (
                getQueryStatus(_queryId) == Witnet.QueryStatus.Posted
            ) {
                WitOracleDataLib.Query storage __query = WitOracleDataLib.seekQuery(_queryId);
                if (__query.request.callbackGas > 0) {
                    _expenses += (
                        estimateBaseFeeWithCallback(_evmGasPrice, __query.request.callbackGas)
                            + estimateExtraFee(_evmGasPrice, _evmWitPrice,
                                Witnet.QuerySLA({
                                    witResultMaxSize: uint16(0),
                                    witCommitteeSize: __query.slaParams.witCommitteeSize,
                                    witUnitaryReward: __query.slaParams.witUnitaryReward
                                })
                            )
                    );
                } else {
                    _expenses += (
                        estimateBaseFee(_evmGasPrice)
                            + estimateExtraFee(_evmGasPrice, _evmWitPrice, __query.slaParams)
                    );
                }
                _expenses +=  _evmWitPrice * __query.slaParams.witUnitaryReward;
                _revenues += Witnet.QueryEvmReward.unwrap(__query.reward);
            }
        }
    }

    /// @notice Retrieves the Witnet Data Request bytecodes of previously posted queries.
    /// @dev Returns empty buffer if the query does not exist.
    /// @param _queryIds Query identifies.
    function extractRadonBytecodes(Witnet.QueryId[] memory _queryIds)
        public view 
        virtual override
        returns (bytes[] memory _bytecodes)
    {
        return WitOracleDataLib.extractRadonBytecodes(registry, _queryIds);
    }

    /// Reports the Witnet-provable result to a previously posted request. 
    /// @dev Will assume `block.timestamp` as the timestamp at which the request was solved.
    /// @dev Fails if:
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_witDrTxHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param _queryId The unique identifier of the data request.
    /// @param _witDrTxHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _resultCborBytes The result itself as bytes.
    function reportResult(
            Witnet.QueryId _queryId,
            Witnet.TransactionHash _witDrTxHash,
            bytes calldata _resultCborBytes
        )
        public override
        onlyReporters
        returns (uint256)
    {
        // results cannot be empty:
        _require(
            _resultCborBytes.length != 0, 
            "result cannot be empty"
        );
        // do actual report and return reward transfered to the reproter:
        // solhint-disable not-rely-on-time
        return __reportResultAndReward(
            Witnet.QueryId.unwrap(_queryId),
            Witnet.Timestamp.wrap(uint64(block.timestamp)),
            _witDrTxHash,
            _resultCborBytes
        );
    }

    /// Reports the Witnet-provable result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_witDrTxHash` is zero;
    /// @dev - length of provided `_resultCborBytes` is zero.
    /// @param _queryId The unique query identifier
    /// @param _resultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param _witDrTxHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _resultCborBytes The result itself as bytes.
    function reportResult(
            Witnet.QueryId _queryId,
            Witnet.Timestamp  _resultTimestamp,
            Witnet.TransactionHash _witDrTxHash,
            bytes calldata _resultCborBytes
        )
        public 
        override
        onlyReporters
        returns (uint256)
    {
        // validate timestamp
        _require(
            !_resultTimestamp.isZero(),
            "bad timestamp"
        );
        // results cannot be empty
        _require(
            _resultCborBytes.length != 0, 
            "result cannot be empty"
        );
        // do actual report and return reward transfered to the reproter:
        return  __reportResultAndReward(
            Witnet.QueryId.unwrap(_queryId),
            _resultTimestamp,
            _witDrTxHash,
            _resultCborBytes
        );
    }

    /// @notice Reports Witnet-provided results to multiple requests within a single EVM tx.
    /// @notice Emits either a WitOracleQueryReport* or a BatchReportError event per batched report.
    /// @dev Fails only if called from unauthorized address.
    /// @param _batchResults Array of BatchResult structs, every one containing:
    ///         - unique query identifier;
    ///         - timestamp of the solving tally txs in Witnet. If zero is provided, EVM-timestamp will be used instead;
    ///         - hash of the corresponding data request tx at the Witnet side-chain level;
    ///         - data request result in raw bytes.
    function reportResultBatch(IWitOracleQueriableTrustableReporter.BatchResult[] memory _batchResults)
        public override
        onlyReporters
        returns (uint256 _batchReward)
    {
        for (uint _i = 0; _i < _batchResults.length; _i ++) {
            uint256 _queryId = Witnet.QueryId.unwrap(_batchResults[_i].queryId);
            if (
                getQueryStatus(_queryId)
                    != Witnet.QueryStatus.Posted
            ) {
                emit BatchReportError(
                    Witnet.QueryId.unwrap(_batchResults[_i].queryId),
                    string(abi.encodePacked(
                        class(),
                        ": ", WitOracleDataLib.notInStatusRevertMessage(Witnet.QueryStatus.Posted)
                    ))
                );
            } else if (
                Witnet.Timestamp.unwrap(_batchResults[_i].resultTimestamp) > uint64(block.timestamp)
                    || _batchResults[_i].resultTimestamp.isZero()
                    || _batchResults[_i].resultCborBytes.length == 0
            ) {
                emit BatchReportError(
                    Witnet.QueryId.unwrap(_batchResults[_i].queryId), 
                    string(abi.encodePacked(
                        class(),
                        ": invalid report data"
                    ))
                );
            } else {
                _batchReward += __reportResult(
                    Witnet.QueryId.unwrap(_batchResults[_i].queryId),
                    _batchResults[_i].resultTimestamp,
                    _batchResults[_i].drTxHash,
                    _batchResults[_i].resultCborBytes
                );
            }
        }   
        // Transfer rewards to all reported results in one single transfer to the reporter:
        if (_batchReward > 0) {
            __safeTransferTo(
                payable(msg.sender),
                _batchReward
            );
        }
    }


    /// ================================================================================================================
    /// --- Internal methods -------------------------------------------------------------------------------------------

    function __queryData(
            address _requester,
            uint24  _callbackGas,
            uint72  _evmReward,
            Witnet.RadonHash _radonHash,
            Witnet.QuerySLA memory _querySLA
        ) 
        virtual override
        internal
        returns (uint256 _queryId)
    {
        _queryId = super.__queryData(
            _requester,
            _callbackGas,
            _evmReward,
            _radonHash,
            _querySLA
        );
        // todo: deprecate legacy events
        emit IWitOracleLegacy.WitnetQuery(
            _queryId, 
            msg.value, 
            IWitOracleLegacy.RadonSLA({
                witCommitteeSize: uint8(_querySLA.witCommitteeSize),
                witUnitaryReward: _querySLA.witUnitaryReward
            })
        );
    }

    function __reportResult(
            uint256 _queryId,
            Witnet.Timestamp  _resultTimestamp,
            Witnet.TransactionHash _witDrTxHash,
            bytes memory _resultCborBytes
        )
        virtual internal
        returns (uint256)
    {
        _require(
            WitOracleDataLib.getQueryStatus(_queryId) == Witnet.QueryStatus.Posted,
            "not in Posted status"
        );
        return WitOracleDataLib.reportResult(
            msg.sender,
            tx.gasprice,
            uint64(block.number),
            _queryId, 
            _resultTimestamp, 
            _witDrTxHash, 
            _resultCborBytes
        );
    }

    function __reportResultAndReward(
            uint256 _queryId,
            Witnet.Timestamp  _resultTimestamp,
            Witnet.TransactionHash _witDrTxHash,
            bytes calldata _resultCborBytes
        )
        virtual internal
        returns (uint256 _evmReward)
    {
        _evmReward = __reportResult(
            _queryId, 
            _resultTimestamp, 
            _witDrTxHash, 
            _resultCborBytes
        );
        // transfer reward to reporter
        __safeTransferTo(
            payable(msg.sender),
            _evmReward
        );
    }
}
