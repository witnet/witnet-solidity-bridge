// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBaseQueriable.sol";
import "../WitnetUpgradableBase.sol";
import "../../interfaces/IWitOracleTrustableAdmin.sol";
import "../../interfaces/IWitOracleQueriable.sol";
import "../../interfaces/IWitOracleTrustableReporter.sol";
import "../../interfaces/legacy/IWitOracleLegacy.sol";

/// @title Queriable WitOracle "trustable" base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBaseQueriableTrustable
    is
        WitnetUpgradableBase,
        WitOracleBaseQueriable,
        IWitOracleTrustableAdmin,
        IWitOracleLegacy,
        IWitOracleTrustableReporter
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
        emit DataReport(tx.origin, msg.sender, _evmSigner, _result);
        return _result;
    }


    // ================================================================================================================
    // --- IWitOracleQueriable ----------------------------------------------------------------------------------------

    /// @notice Removes all query data from storage. Pays back reward on expired queries.
    /// @dev Fails if the query is not in a final status, or not called from the actual requester.
    function deleteQuery(Witnet.QueryId _queryId)
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
    function getQueryStatus(Witnet.QueryId _queryId) 
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
        registry.lookupRadonRequestResultDataType(Witnet.RadonHash.wrap(radHash));

        // Base fee is actually invariant to max result size:
        return estimateBaseFee(gasPrice);
    }

    function fetchQueryResponse(uint256 queryId) virtual override external returns (bytes memory) {
        deleteQuery(Witnet.QueryId.wrap(uint64(queryId)));
        return hex"";
    }

    function getQueryResponseStatus(uint256 queryId) virtual override public view returns (IWitOracleLegacy.QueryResponseStatus) {
        return WitOracleDataLib.getQueryResponseStatus(
            Witnet.QueryId.wrap(uint64(queryId))
        );
    }

    function getQueryResultCborBytes(uint256 queryId) virtual override external view returns (bytes memory) {
        return getQueryResponse(Witnet.QueryId.wrap(uint64(queryId))).resultCborBytes;
    }

    function getQueryResultError(uint256 queryId) virtual override external view returns (IWitOracleLegacy.ResultError memory) {
        Witnet.DataResult memory _result = getQueryResult(
            Witnet.QueryId.wrap(uint64(queryId))
        );
        return IWitOracleLegacy.ResultError({
            code: uint8(_result.status),
            reason: WitOracleResultStatusLib.toString(_result)
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
        return Witnet.QueryId.unwrap(
            postQuery(
                Witnet.RadonHash.wrap(_queryRadHash),
                Witnet.QuerySLA({
                    witResultMaxSize: 32,
                    witCommitteeSize: _querySLA.witCommitteeSize,
                    witInclusionFees: _querySLA.witUnitaryReward * 3
                })
            )
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
        return Witnet.QueryId.unwrap(
            postQuery(
                Witnet.RadonHash.wrap(_queryRadHash),
                Witnet.QuerySLA({
                    witResultMaxSize: 32,
                    witCommitteeSize: _querySLA.witCommitteeSize,
                    witInclusionFees: _querySLA.witUnitaryReward * 3
                }),
                Witnet.QueryCallback({
                    consumer: msg.sender,
                    gasLimit: _queryCallbackGas
                })
            )
        );
    }

    function postRequestWithCallback(
            bytes calldata _queryRadBytecode,
            IWitOracleLegacy.RadonSLA calldata _querySLA,
            uint24 _queryCallbackGas
        )
        virtual override
        external payable
        returns (uint256)
    {
        return Witnet.QueryId.unwrap(
            postQuery(
                _queryRadBytecode,
                Witnet.QuerySLA({
                    witResultMaxSize: 32,
                    witCommitteeSize: _querySLA.witCommitteeSize,
                    witInclusionFees: _querySLA.witUnitaryReward * 3
                }),
                Witnet.QueryCallback({
                    consumer: msg.sender,
                    gasLimit: _queryCallbackGas
                })
            )
        );
    }


    // =========================================================================================================================
    // --- Implements IWitOracleTrustableReporter ------------------------------------------------------------------------------

    /// @notice Estimates the actual earnings (or loss), in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    function estimateReportEarnings(
            Witnet.QueryId[] calldata _queryIds, 
            bytes calldata,
            uint256 _evmGasPrice,
            uint256 _evmWitPrice
        )
        external view
        virtual override
        returns (uint256 _revenues, uint256 _expenses)
    {
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            Witnet.QueryId _queryId = _queryIds[_ix];
            if (
                getQueryStatus(_queryId) == Witnet.QueryStatus.Posted
            ) {
                Witnet.Query storage __query = WitOracleDataLib.seekQuery(_queryId);
                if (__query.request.callbackGas > 0) {
                    _expenses += (
                        estimateBaseFeeWithCallback(_evmGasPrice, __query.request.callbackGas)
                            + estimateExtraFee(_evmGasPrice, _evmWitPrice,
                                Witnet.QuerySLA({
                                    witResultMaxSize: uint16(0),
                                    witCommitteeSize: __query.slaParams.witCommitteeSize,
                                    witInclusionFees: __query.slaParams.witInclusionFees
                                })
                            )
                    );
                } else {
                    _expenses += (
                        estimateBaseFee(_evmGasPrice)
                            + estimateExtraFee(_evmGasPrice, _evmWitPrice, __query.slaParams)
                    );
                }
                _expenses +=  _evmWitPrice * __query.slaParams.witInclusionFees;
                _revenues += Witnet.QueryEvmReward.unwrap(__query.reward);
            }
        }
    }

    /// @notice Retrieves the Witnet Data Request bytecodes of previously posted queries.
    /// @dev Returns empty buffer if the query does not exist.
    /// @param _queryIds Query identifies.
    function extractRadonRequests(Witnet.QueryId[] calldata _queryIds)
        external view 
        virtual override
        returns (bytes[] memory _bytecodes)
    {
        return WitOracleDataLib.extractRadonRequests(registry, _queryIds);
    }

    /// Reports the Witnet-provable result to a previously posted request. 
    /// @dev Will assume `block.timestamp` as the timestamp at which the request was solved.
    /// @dev Fails if:
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_resultTallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param _queryId The unique identifier of the data request.
    /// @param _resultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _resultCborBytes The result itself as bytes.
    function reportResult(
            Witnet.QueryId _queryId,
            Witnet.TransactionHash _resultTallyHash,
            bytes calldata _resultCborBytes
        )
        external override
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
            _queryId,
            Witnet.Timestamp.wrap(uint64(block.timestamp)),
            _resultTallyHash,
            _resultCborBytes
        );
    }

    /// Reports the Witnet-provable result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_resultTallyHash` is zero;
    /// @dev - length of provided `_resultCborBytes` is zero.
    /// @param _queryId The unique query identifier
    /// @param _resultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param _resultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _resultCborBytes The result itself as bytes.
    function reportResult(
            Witnet.QueryId _queryId,
            Witnet.Timestamp  _resultTimestamp,
            Witnet.TransactionHash _resultTallyHash,
            bytes calldata _resultCborBytes
        )
        external
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
            _queryId,
            _resultTimestamp,
            _resultTallyHash,
            _resultCborBytes
        );
    }

    /// @notice Reports Witnet-provided results to multiple requests within a single EVM tx.
    /// @notice Emits either a WitOracleQueryResponse* or a BatchReportError event per batched report.
    /// @dev Fails only if called from unauthorized address.
    /// @param _batchResults Array of BatchResult structs, every one containing:
    ///         - unique query identifier;
    ///         - timestamp of the solving tally txs in Witnet. If zero is provided, EVM-timestamp will be used instead;
    ///         - hash of the corresponding data request tx at the Witnet side-chain level;
    ///         - data request result in raw bytes.
    function reportResultBatch(IWitOracleTrustableReporter.BatchResult[] calldata _batchResults)
        external override
        onlyReporters
        returns (uint256 _batchReward)
    {
        for (uint _i = 0; _i < _batchResults.length; _i ++) {
            Witnet.QueryId _queryId = _batchResults[_i].queryId;
            if (
                getQueryStatus(_queryId)
                    != Witnet.QueryStatus.Posted
            ) {
                emit BatchReportError(
                    _batchResults[_i].queryId,
                    string(abi.encodePacked(
                        class(),
                        ": ", WitOracleDataLib.notInStatusRevertMessage(Witnet.QueryStatus.Posted)
                    ))
                );
            } else if (
                Witnet.Timestamp.unwrap(_batchResults[_i].drTxTimestamp) > uint64(block.timestamp)
                    || _batchResults[_i].drTxTimestamp.isZero()
                    || _batchResults[_i].resultCborBytes.length == 0
            ) {
                emit BatchReportError(
                    _batchResults[_i].queryId, 
                    string(abi.encodePacked(
                        class(),
                        ": invalid report data"
                    ))
                );
            } else {
                _batchReward += __reportResult(
                    _batchResults[_i].queryId,
                    _batchResults[_i].drTxTimestamp,
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

    function __postQuery(
            address _requester,
            uint24  _callbackGas,
            uint72  _evmReward,
            Witnet.RadonHash _radonHash,
            Witnet.QuerySLA memory _querySLA
        ) 
        virtual override
        internal
        returns (Witnet.QueryId _queryId)
    {
        _queryId = super.__postQuery(
            _requester,
            _callbackGas,
            _evmReward,
            _radonHash,
            _querySLA
        );
        emit IWitOracleLegacy.WitnetQuery(
            Witnet.QueryId.unwrap(_queryId), 
            msg.value, 
            IWitOracleLegacy.RadonSLA({
                witCommitteeSize: uint8(_querySLA.witCommitteeSize),
                witUnitaryReward: _querySLA.witInclusionFees / 3
            })
        );
    }

    function __postQuery(
            address _requester,
            uint24  _callbackGas,
            uint72  _evmReward,
            bytes calldata _radonRadBytecode,
            Witnet.QuerySLA memory _querySLA
        ) 
        virtual override
        internal
        returns (Witnet.QueryId _queryId)
    {
        _queryId = super.__postQuery(
            _requester,
            _callbackGas,
            _evmReward,
            _radonRadBytecode,
            _querySLA
        );
        emit IWitOracleLegacy.WitnetQuery(
            Witnet.QueryId.unwrap(_queryId), 
            msg.value, 
            IWitOracleLegacy.RadonSLA({
                witCommitteeSize: uint8(_querySLA.witCommitteeSize),
                witUnitaryReward: _querySLA.witInclusionFees / 3
            })
        );
    }

    function __reportResult(
            Witnet.QueryId _queryId,
            Witnet.Timestamp  _resultTimestamp,
            Witnet.TransactionHash _resultTallyHash,
            bytes calldata _resultCborBytes
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
            _resultTallyHash, 
            _resultCborBytes
        );
    }

    function __reportResultAndReward(
            Witnet.QueryId _queryId,
            Witnet.Timestamp  _resultTimestamp,
            Witnet.TransactionHash _resultTallyHash,
            bytes calldata _resultCborBytes
        )
        virtual internal
        returns (uint256 _evmReward)
    {
        _evmReward = __reportResult(
            _queryId, 
            _resultTimestamp, 
            _resultTallyHash, 
            _resultCborBytes
        );
        // transfer reward to reporter
        __safeTransferTo(
            payable(msg.sender),
            _evmReward
        );
    }
}
