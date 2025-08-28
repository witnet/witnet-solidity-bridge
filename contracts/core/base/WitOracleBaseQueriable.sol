// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBasePushOnly.sol";

import "../../WitOracle.sol";
import "../../data/WitOracleDataLib.sol";
import "../../interfaces/IWitOracleQueriableConsumer.sol";
import "../../libs/WitOracleResultStatusLib.sol";
import "../../patterns/Payable.sol";

/// @title Queriable WitOracle base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBaseQueriable
    is 
        Payable,
        WitOracle
{
    using Witnet for Witnet.QuerySLA;
    using WitOracleDataLib for WitOracleDataLib.Storage;

    function channel() virtual override public view returns (bytes4) {
        return Witnet.channel(address(this));
    }

    IWitOracleRadonRegistry public immutable override registry;

    uint256 internal immutable __reportResultGasBase;
    uint256 internal immutable __reportResultWithCallbackGasBase;
    uint256 internal immutable __reportResultWithCallbackRevertGasBase;
    uint256 internal immutable __sstoreFromZeroGas;

    modifier checkQueryCallback(Witnet.QueryCallback memory callback) virtual {
        _require(
            address(callback.consumer).code.length > 0
                && IWitOracleQueriableConsumer(callback.consumer).reportableFrom(address(this))
                && callback.gasLimit > 0,
            "invalid callback"
        ); _;
    }

    modifier checkQueryReward(uint256 _msgValue, uint256 _baseFee) virtual {
        _require(
            _msgValue >= _baseFee, 
            "insufficient reward"
        ); 
        _require(
            _msgValue <= _baseFee * 10,
            "too much reward"
        ); _;
    }

    modifier checkQuerySLA(Witnet.QuerySLA memory sla) virtual {
        _require(
            sla.isValid(), 
            "invalid SLA"
        ); _;
    }

    /// Asserts the given query is currently in the given status.
    modifier inStatus(uint256 _queryId, Witnet.QueryStatus _status) {
        if (getQueryStatus(_queryId) != _status) {
            _revert(WitOracleDataLib.notInStatusRevertMessage(_status));
        } else {
            _;
        }
    }

    /// Asserts the caller actually posted the referred query.
    modifier onlyRequester(uint256 _queryId) {
        _require(
            msg.sender == WitOracleDataLib.seekQueryRequest(_queryId).requester, 
            "not the requester"
        ); _;
    }

    struct EvmImmutables {
        uint32 reportResultGasBase;
        uint32 reportResultWithCallbackGasBase;
        uint32 reportResultWithCallbackRevertGasBase;
        uint32 sstoreFromZeroGas;
    }
    
    constructor(
            EvmImmutables memory _immutables,
            WitOracleRadonRegistry _registry
        )
    {
        _require(
            address(_registry).code.length > 0,
            "inexistent registry"
        );
        _require(
            _registry.specs() == type(IWitOracleRadonRegistry).interfaceId, 
            "uncompliant registry"
        );
        registry = _registry;

        __reportResultGasBase = _immutables.reportResultGasBase;
        __reportResultWithCallbackGasBase = _immutables.reportResultWithCallbackGasBase;
        __reportResultWithCallbackRevertGasBase = _immutables.reportResultWithCallbackRevertGasBase;
        __sstoreFromZeroGas = _immutables.sstoreFromZeroGas;
    }

    function getQueryStatus(uint256) virtual public view returns (Witnet.QueryStatus);

    
    // ================================================================================================================
    // --- Payable ----------------------------------------------------------------------------------------------------

    /// Gets current transaction price.
    function _getGasPrice() internal view virtual override returns (uint256) {
        return tx.gasprice;
    }

    /// Gets message actual sender.
    function _getMsgSender() internal view virtual override returns (address) {
        return msg.sender;
    }
    
    /// Gets current payment value.
    function _getMsgValue() internal view virtual override returns (uint256) {
        return msg.value;
    }

    /// Transfers ETHs to given address.
    /// @param _to Recipient address.
    /// @param _amount Amount of ETHs to transfer.
    function __safeTransferTo(address payable _to, uint256 _amount) virtual override internal {
        payable(_to).transfer(_amount);
    }
    
    
    // ================================================================================================================
    // --- IWitOracle (partial) ---------------------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @param _evmGasPrice Expected gas price to pay upon posting the data request.
    function estimateBaseFee(uint256 _evmGasPrice)
        public view
        virtual override
        returns (uint256)
    {
        return _evmGasPrice * (
            __reportResultGasBase 
                + 4 * __sstoreFromZeroGas
        );
    }

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _evmGasPrice Expected gas price to pay upon posting the data request.
    /// @param _evmCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _evmGasPrice, uint24 _evmCallbackGasLimit)
        public view
        virtual override
        returns (uint256)
    {
        uint _reportResultWithCallbackGasThreshold = (
            __reportResultWithCallbackRevertGasBase
                + 3 * __sstoreFromZeroGas
        );
        if (
            _evmCallbackGasLimit < _reportResultWithCallbackGasThreshold
                || __reportResultWithCallbackGasBase + _evmCallbackGasLimit < _reportResultWithCallbackGasThreshold
        ) {
            return (
                _evmGasPrice
                    * _reportResultWithCallbackGasThreshold
            );
        } else {
            return (
                _evmGasPrice 
                    * (
                        __reportResultWithCallbackGasBase
                            + _evmCallbackGasLimit
                    )
            );
        }
    }

    /// @notice Estimate the extra reward (i.e. over the base fee) to be paid when posting a new
    /// @notice data query in order to avoid getting provable "too low incentives" results from
    /// @notice the Wit/Oracle blockchain. 
    /// @dev The extra fee gets calculated in proportion to:
    /// @param _evmGasPrice Tentative EVM gas price at the moment the query result is ready.
    /// @param _evmWitPrice Tentative nanoWit price in Wei at the moment the query is solved on the Wit/Oracle blockchain.
    /// @param _querySLA The query SLA data security parameters as required for the Wit/Oracle blockchain. 
    function estimateExtraFee(
            uint256 _evmGasPrice, 
            uint256 _evmWitPrice, 
            Witnet.QuerySLA memory _querySLA
        )
        public view
        virtual override
        returns (uint256)
    {
        return (
            _evmWitPrice * _querySLA.witUnitaryReward
                + (_querySLA.witResultMaxSize > 32
                    ? _evmGasPrice * __sstoreFromZeroGas * ((_querySLA.witResultMaxSize - 32) / 32)
                    : 0
                )
        );
    }

    /// Gets the whole Query data contents, if any, no matter its current status.
    function getQuery(uint256 _queryId)
      public view
      virtual override
      returns (Witnet.Query memory)
    {
        return __storage().queries[_queryId];
    }

    /// @notice Gets the current EVM reward the report can claim, if not done yet.
    function getQueryEvmReward(uint256 _queryId) 
        external view 
        virtual override
        returns (Witnet.QueryEvmReward)
    {
        return __storage().queries[_queryId].reward;
    }

    /// @notice Retrieves the RAD hash and SLA parameters of the given query.
    /// @param _queryId The unique query identifier.
    function getQueryRequest(uint256 _queryId)
        external view override
        returns (Witnet.QueryRequest memory)
    {
        return WitOracleDataLib.seekQueryRequest(_queryId);
    }

    /// Retrieves the Witnet-provable result, and metadata, to a previously posted request.    
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier
    function getQueryResponse(uint256 _queryId)
        virtual override public view
        returns (Witnet.QueryResponse memory)
    {
        return WitOracleDataLib.seekQueryResponse(_queryId);
    }

    function getQueryResult(uint256 _queryId)
        virtual override public view 
        returns (Witnet.DataResult memory)
    {
        return WitOracleDataLib.getQueryResult(_queryId);
    }

    function getQueryResultStatus(uint256 _queryId)
        virtual override public view 
        returns (Witnet.ResultStatus)
    {
        return WitOracleDataLib.getQueryResultStatus(_queryId);
    }

    function getQueryResultStatusDescription(uint256 _queryId)
        virtual override public view
        returns (string memory)
    {
        return WitOracleResultStatusLib.toString(
            abi.encode(WitOracleDataLib.getQueryResult(_queryId))
        );
    }

    /// @notice Gets query's result back tracing trails
    function getQueryResultTrails(uint256 _queryId) 
        virtual override
        external view returns (
            bytes32 queryUUID,
            Witnet.TransactionHash resultDrTxHash,
            Witnet.Timestamp resultTimestamp,
            uint256 resultFinalityBlock
        )
    {
        Witnet.Query storage __query = WitOracleDataLib.seekQuery(_queryId);
        queryUUID = bytes32(Witnet.QueryHash.unwrap(__query.hash));
        resultDrTxHash = __query.response.resultDrTxHash;
        resultTimestamp = __query.response.resultTimestamp;
        resultFinalityBlock = Witnet.BlockNumber.unwrap(__query.checkpoint);
    }

    function getQueryStatusString(uint256 _queryId)
        virtual override external view 
        returns (string memory)
    {
        return WitOracleDataLib.toString(
            getQueryStatus(_queryId)
        );
    }

    function getQueryStatusBatch(uint256[] calldata _queryIds)
        virtual override
        public view
        returns (Witnet.QueryStatus[] memory _status)
    {
        _status = new Witnet.QueryStatus[](_queryIds.length);
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            _status[_ix] = getQueryStatus(_queryIds[_ix]);
        }
    }

    /// @notice Returns next query id to be generated by the Witnet Request Board.
    function getNextQueryId()
        external view
        override
        returns (Witnet.QueryId)
    {
        return Witnet.QueryId.wrap(__storage().nonce + 1);
    }

    function queryData(
            Witnet.RadonHash _queryRAD, 
            Witnet.QuerySLA memory _querySLA
        )
        virtual override
        public payable
        checkQueryReward(
            _getMsgValue(),
            estimateBaseFee(_getGasPrice())
        )
        checkQuerySLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __queryData(
            _getMsgSender(), 0,
            uint72(_getMsgValue()),
            _queryRAD,
            _querySLA
        );
        // Let Web3 observers know that a new request has been posted
        emit WitOracleQuery(
            _getMsgSender(),
            _getGasPrice(),
            _getMsgValue(),
            Witnet.QueryId.wrap(uint64(_queryId)),
            _queryRAD, 
            _querySLA
        );
    }
   
    function queryDataWithCallback(
            Witnet.RadonHash _queryRAD, 
            Witnet.QuerySLA memory _querySLA,
            Witnet.QueryCallback memory _queryCallback
        )
        virtual override
        public payable
        checkQueryReward(
            _getMsgValue(),
            estimateBaseFeeWithCallback(
                _getGasPrice(),  
                _queryCallback.gasLimit
            )
        )
        checkQuerySLA(_querySLA)
        checkQueryCallback(_queryCallback)
        returns (uint256 _queryId)
    {
        _queryId = __queryData(
            _queryCallback.consumer,
            _queryCallback.gasLimit,
            uint72(_getMsgValue()),
            _queryRAD,
            _querySLA
        );
        emit WitOracleQuery(
            _getMsgSender(),
            _getGasPrice(),
            _getMsgValue(),
            Witnet.QueryId.wrap(uint64(_queryId)), 
            _queryRAD, 
            _querySLA
        );
    } 

    /// Increments the reward of a previously posted request by adding the transaction value to it.
    /// @dev Fails if the `_queryId` is not in 'Posted' status.
    /// @param _queryId The unique query identifier.
    function upgradeQueryEvmReward(uint256 _queryId)
        external payable
        virtual override      
        inStatus(_queryId, Witnet.QueryStatus.Posted)
    {
        Witnet.Query storage __query = WitOracleDataLib.seekQuery(_queryId);
        uint256 _newReward = (
            Witnet.QueryEvmReward.unwrap(__query.reward)
                + _getMsgValue()
        );
        __query.reward = Witnet.QueryEvmReward.wrap(uint72(_newReward));
        emit WitOracleQueryUpgrade(
            Witnet.QueryId.wrap(uint64(_queryId)),
            _getMsgSender(),
            _getGasPrice(),
            _newReward
        );
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function __queryData(
            address _requester,
            uint24  _callbackGas,
            uint72  _evmReward,
            Witnet.RadonHash _radonHash,
            Witnet.QuerySLA memory _querySLA
        )
        virtual internal
        returns (uint256 _queryId)
    {
        _queryId = ++ __storage().nonce;
        Witnet.Query storage __query = WitOracleDataLib.seekQuery(_queryId);
        __query.checkpoint = Witnet.BlockNumber.wrap(uint64(block.number));
        __query.hash = Witnet.hashify(
            Witnet.QueryId.wrap(uint64(_queryId)), 
            _radonHash, 
            _querySLA.hashify()
        );
        __query.reward = Witnet.QueryEvmReward.wrap(_evmReward);
        __query.request.requester = _requester;
        __query.request.radonHash = _radonHash;
        if (_callbackGas > 0) __query.request.callbackGas = _callbackGas;
        __query.slaParams = _querySLA;
    }

    function _revertUnhandledException() virtual internal view {
        _revert(_revertUnhandledExceptionReason());
    }

    function _revertUnhandledExceptionReason() virtual internal pure returns (string memory) {
        return string(abi.encodePacked(
            type(WitOracleDataLib).name,
            ": unhandled assertion"
        ));
    }

    /// Returns storage pointer to contents of 'WitOracleDataLib.Storage' struct.
    function __storage() virtual internal pure returns (WitOracleDataLib.Storage storage _ptr) {
        return WitOracleDataLib.data();
    }    
}
