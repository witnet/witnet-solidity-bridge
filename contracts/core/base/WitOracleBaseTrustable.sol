// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBase.sol";
import "../WitnetUpgradableBase.sol";
import "../../interfaces/IWitOracleAdminACLs.sol";
import "../../interfaces/IWitOracleLegacy.sol";
import "../../interfaces/IWitOracleReporter.sol";

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
        IWitOracleReporter
{
    using Witnet for Witnet.RadonSLA;

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

    /// Retrieves copy of all response data related to a previously posted request, removing the whole query from storage.
    /// @dev Fails if the `_queryId` is not in 'Finalized' or 'Expired' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @dev If in 'Expired' status, query reward is transfer back to the requester.
    /// @param _queryId The unique query identifier.
    function fetchQueryResponse(Witnet.QueryId _queryId)
        virtual override external
        returns (Witnet.QueryResponse memory)
    {
        try WitOracleDataLib.fetchQueryResponse(
            _queryId
        
        ) returns (
            Witnet.QueryResponse memory queryResponse,
            Witnet.QueryReward queryEvmExpiredReward
        ) {
            uint256 _queryEvmExpiredReward = Witnet.QueryReward.unwrap(queryEvmExpiredReward);
            if (_queryEvmExpiredReward > 0) {
                // transfer unused reward to requester, only if the query expired:
                __safeTransferTo(
                    payable(msg.sender),
                    _queryEvmExpiredReward
                );
            }
            return queryResponse;
        
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

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query has been succesfully solved;
    /// @notice   - 3 => Error: the query couldn't get solved due to some issue.
    /// @param _queryId The unique query identifier.
    function getQueryResponseStatus(Witnet.QueryId _queryId)
        virtual override public view
        returns (Witnet.QueryResponseStatus)
    {
        return WitOracleDataLib.getQueryResponseStatus(_queryId);
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
    /// --- IWitOracleLegacy ---------------------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function estimateBaseFee(uint256 _gasPrice, uint16 _resultMaxSize)
        public view
        virtual override
        returns (uint256)
    {
        return _gasPrice * (
            __reportResultGasBase
                + __sstoreFromZeroGas * (
                    4 + (_resultMaxSize == 0 ? 0 : _resultMaxSize - 1) / 32
                )
        );
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

    function postRequest(
            bytes32 _queryRadHash, 
            IWitOracleLegacy.RadonSLA calldata _querySLA
        )
        virtual override
        external payable
        returns (uint256)
    {
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


    function postRequestWithCallback(
            bytes32 _queryRadHash,
            IWitOracleLegacy.RadonSLA calldata _querySLA,
            uint24 _queryCallbackGas
        )
        virtual override
        external payable
        returns (uint256)
    {
        return postQueryWithCallback(
            _queryRadHash,
            Witnet.RadonSLA({
                witNumWitnesses: _querySLA.witNumWitnesses,
                witUnitaryReward: _querySLA.witUnitaryReward,
                maxTallyResultSize: 32
            }),
            _queryCallbackGas
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
        return postQueryWithCallback(
            _queryRadBytecode,
            Witnet.RadonSLA({
                witNumWitnesses: _querySLA.witNumWitnesses,
                witUnitaryReward: _querySLA.witUnitaryReward,
                maxTallyResultSize: 32
            }),
            _queryCallbackGas
        );
    }


    // ================================================================================================================
    // --- Implements IWitOracleReporter ------------------------------------------------------------------------------

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
                    WitOracleDataLib.notInStatusRevertMessage(Witnet.QueryStatus.Posted)
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
