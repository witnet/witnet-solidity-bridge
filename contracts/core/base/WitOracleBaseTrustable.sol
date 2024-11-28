// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBase.sol";
import "../WitnetUpgradableBase.sol";
import "../../interfaces/IWitOracleAdminACLs.sol";
import "../../interfaces/IWitOracleLegacy.sol";
import "../../interfaces/IWitOracleTrustable.sol";
import "../../interfaces/IWitOracleTrustableReporter.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleBaseTrustable
    is
        WitOracleBase,
        WitnetUpgradableBase,
        IWitOracleAdminACLs,
        IWitOracleLegacy,
        IWitOracleTrustable,
        IWitOracleTrustableReporter
{
    using Witnet for Witnet.DataPushReport;
    using Witnet for Witnet.QuerySLA;

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

    /// @notice Removes all query data from storage. Pays back reward on expired queries.
    /// @dev Fails if the query is not in a final status, or not called from the actual requester.
    function deleteQuery(Witnet.QueryId _queryId)
        virtual override public
        returns (Witnet.QueryReward)
    {
        try WitOracleDataLib.deleteQuery(
            _queryId
        
        ) returns (
            Witnet.QueryReward _queryReward
        ) {
            uint256 _evmPayback = Witnet.QueryReward.unwrap(_queryReward);
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
            _revertWitOracleDataLibUnhandledException();
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
    // --- Implements IWitOracleAdminACLs -----------------------------------------------------------------------------

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
        registry.lookupRadonRequestResultDataType(radHash);

        // Base fee is actually invariant to max result size:
        return estimateBaseFee(gasPrice);
    }

    function fetchQueryResponse(uint256 queryId) virtual override external returns (bytes memory) {
        deleteQuery(Witnet.QueryId.wrap(queryId));
        return hex"";
    }

    function getQueryResponseStatus(uint256 queryId) virtual override public view returns (IWitOracleLegacy.QueryResponseStatus) {
        return WitOracleDataLib.getQueryResponseStatus(
            Witnet.QueryId.wrap(queryId)
        );
    }

    function getQueryResultCborBytes(uint256 queryId) virtual override external view returns (bytes memory) {
        return getQueryResponse(Witnet.QueryId.wrap(queryId)).resultCborBytes;
    }

    function getQueryResultError(uint256 queryId) virtual override external view returns (IWitOracleLegacy.ResultError memory) {
        Witnet.DataResult memory _result = getQueryResult(
            Witnet.QueryId.wrap(queryId)
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
                _queryRadHash,
                Witnet.QuerySLA({
                    witCommitteeCapacity: _querySLA.witCommitteeCapacity,
                    witCommitteeUnitaryReward: _querySLA.witCommitteeUnitaryReward,
                    witResultMaxSize: 32,
                    witCapability: Witnet.QueryCapability.wrap(0)
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
                _queryRadHash,
                Witnet.QuerySLA({
                    witCommitteeCapacity: uint8(_querySLA.witCommitteeCapacity),
                    witCommitteeUnitaryReward: _querySLA.witCommitteeUnitaryReward,
                    witResultMaxSize: 32,
                    witCapability: Witnet.QueryCapability.wrap(0)
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
                    witCommitteeCapacity: _querySLA.witCommitteeCapacity,
                    witCommitteeUnitaryReward: _querySLA.witCommitteeUnitaryReward,
                    witResultMaxSize: 32,
                    witCapability: Witnet.QueryCapability.wrap(0)
                }),
                Witnet.QueryCallback({
                    consumer: msg.sender,
                    gasLimit: _queryCallbackGas
                })
            )
        );
    }


    // =========================================================================================================================
    // --- Implements IWitOracleTrustable --------------------------------------------------------------------------------------

    /// @notice Verify the push data report is valid and was actually signed by a trustable reporter,
    /// @notice reverting if verification fails, or returning a Witnet.DataResult struct otherwise.
    function pushData(Witnet.DataPushReport calldata _report, bytes calldata _signature) 
        virtual override external 
        checkQuerySLA(_report.witDrSLA)
        returns (Witnet.DataResult memory)
    {
        _require(
            __storage().reporters[Witnet.recoverAddr(_signature, _report.tallyHash())],
            "unauthorized reporter"
        );
        return WitOracleDataLib.intoDataResult(
            Witnet.QueryResponse({
                reporter: address(0), disputer: address(0), _0: 0, 
                resultCborBytes: _report.witDrResultCborBytes,
                resultDrTxHash: _report.witDrTxHash,
                resultTimestamp: Witnet.determineTimestampFromEpoch(_report.witDrResultEpoch)
            }), 
            Witnet.QueryStatus.Finalized
        );
    }

    /// @notice Verify the push data report is valid, reverting if not valid or not reported from an authorized 
    /// @notice reporter, or returning a Witnet.DataResult struct otherwise.
    function pushData(Witnet.DataPushReport calldata _report)
        virtual override external
        checkQuerySLA(_report.witDrSLA)
        onlyReporters
        returns (Witnet.DataResult memory)
    {
        return WitOracleDataLib.intoDataResult(
            Witnet.QueryResponse({
                reporter: address(0), disputer: address(0), _0: 0, 
                resultCborBytes: _report.witDrResultCborBytes,
                resultDrTxHash: _report.witDrTxHash,
                resultTimestamp: Witnet.determineTimestampFromEpoch(_report.witDrResultEpoch)
            }), 
            Witnet.QueryStatus.Finalized
        );
    }


    // =========================================================================================================================
    // --- Implements IWitOracleTrustableReporter ------------------------------------------------------------------------------

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
            Witnet.QueryId _queryId = Witnet.QueryId.wrap(_queryIds[_ix]);
            if (
                getQueryStatus(_queryId) == Witnet.QueryStatus.Posted
            ) {
                Witnet.Query storage __query = WitOracleDataLib.seekQuery(_queryId);
                if (__query.request.callbackGas > 0) {
                    _expenses += (
                        estimateBaseFeeWithCallback(_evmGasPrice, __query.request.callbackGas)
                            + estimateExtraFee(_evmGasPrice, _evmWitPrice,
                                Witnet.QuerySLA({
                                    witCommitteeCapacity: __query.slaParams.witCommitteeCapacity,
                                    witCommitteeUnitaryReward: __query.slaParams.witCommitteeUnitaryReward,
                                    witResultMaxSize: uint16(0),
                                    witCapability: Witnet.QueryCapability.wrap(0)
                                })
                            )
                    );
                } else {
                    _expenses += (
                        estimateBaseFee(_evmGasPrice)
                            + estimateExtraFee(_evmGasPrice, _evmWitPrice, __query.slaParams)
                    );
                }
                _expenses +=  _evmWitPrice * __query.slaParams.witCommitteeUnitaryReward;
                _revenues += Witnet.QueryReward.unwrap(__query.reward);
            }
        }
    }

    /// @notice Retrieves the Witnet Data Request bytecodes and SLAs of previously posted queries.
    /// @dev Returns empty buffer if the query does not exist.
    /// @param _queryIds Query identifies.
    function extractWitnetDataRequests(uint256[] calldata _queryIds)
        external view 
        virtual override
        returns (bytes[] memory _bytecodes)
    {
        return WitOracleDataLib.extractWitnetDataRequests(registry, _queryIds);
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
            uint256 _queryId,
            bytes32 _resultTallyHash,
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
            uint32(block.timestamp),
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
            uint256 _queryId,
            uint32  _resultTimestamp,
            bytes32 _resultTallyHash,
            bytes calldata _resultCborBytes
        )
        external
        override
        onlyReporters
        returns (uint256)
    {
        // validate timestamp
        _require(
            _resultTimestamp > 0,
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
            Witnet.QueryId _queryId = Witnet.QueryId.wrap(_batchResults[_i].queryId);
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
                uint256(_batchResults[_i].resultTimestamp) > block.timestamp
                    || _batchResults[_i].resultTimestamp == 0
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
                    _batchResults[_i].resultTimestamp,
                    _batchResults[_i].resultTallyHash,
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
            bytes32 _radonRadHash,
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
            _radonRadHash,
            _querySLA
        );
        emit IWitOracleLegacy.WitnetQuery(
            Witnet.QueryId.unwrap(_queryId), 
            msg.value, 
            IWitOracleLegacy.RadonSLA({
                witCommitteeCapacity: uint8(_querySLA.witCommitteeCapacity),
                witCommitteeUnitaryReward: _querySLA.witCommitteeUnitaryReward
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
                witCommitteeCapacity: uint8(_querySLA.witCommitteeCapacity),
                witCommitteeUnitaryReward: _querySLA.witCommitteeUnitaryReward
            })
        );
    }

    function __reportResult(
            uint256 _queryId,
            uint32  _resultTimestamp,
            bytes32 _resultTallyHash,
            bytes calldata _resultCborBytes
        )
        virtual internal
        returns (uint256)
    {
        _require(
            WitOracleDataLib.getQueryStatus(Witnet.QueryId.wrap(_queryId)) == Witnet.QueryStatus.Posted,
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
            uint256 _queryId,
            uint32  _resultTimestamp,
            bytes32 _resultTallyHash,
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
