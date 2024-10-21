// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../WitOracle.sol";
import "../../data/WitOracleDataLib.sol";
import "../../interfaces/IWitOracleLegacy.sol";
import "../../interfaces/IWitOracleConsumer.sol";
import "../../libs/WitOracleResultErrorsLib.sol";
import "../../patterns/Payable.sol";

/// @title Witnet Request Board "trustless" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleBase
    is 
        Payable, 
        WitOracle,
        IWitOracleLegacy
{
    using Witnet for Witnet.RadonSLA;
    using WitOracleDataLib for WitOracleDataLib.Storage;

    function channel() virtual override public view returns (bytes4) {
        return WitOracleDataLib.channel();
    }

    // WitOracleRequestFactory public immutable override factory;
    WitOracleRadonRegistry public immutable override registry;

    uint256 internal immutable __reportResultGasBase;
    uint256 internal immutable __reportResultWithCallbackGasBase;
    uint256 internal immutable __reportResultWithCallbackRevertGasBase;
    uint256 internal immutable __sstoreFromZeroGas;

    modifier checkCallbackRecipient(
            IWitOracleConsumer _consumer, 
            uint24 _evmCallbackGasLimit
    ) virtual {
        _require(
            address(_consumer).code.length > 0
                && _consumer.reportableFrom(address(this))
                && _evmCallbackGasLimit > 0,
            "invalid callback"
        ); _;
    }

    modifier checkReward(uint256 _msgValue, uint256 _baseFee) virtual {
        _require(
            _msgValue >= _baseFee, 
            "insufficient reward"
        ); 
        _require(
            _msgValue <= _baseFee * 10,
            "too much reward"
        ); _;
    }

    modifier checkSLA(Witnet.RadonSLA memory sla) virtual {
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
            // WitOracleRequestFactory _factory
        )
    {
        registry = _registry;
        // factory = _factory;

        __reportResultGasBase = _immutables.reportResultGasBase;
        __reportResultWithCallbackGasBase = _immutables.reportResultWithCallbackGasBase;
        __reportResultWithCallbackRevertGasBase = _immutables.reportResultWithCallbackRevertGasBase;
        __sstoreFromZeroGas = _immutables.sstoreFromZeroGas;
    }

    function getQueryStatus(uint256) virtual public view returns (Witnet.QueryStatus);
    function getQueryResponseStatus(uint256) virtual public view returns (Witnet.QueryResponseStatus);

    
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
    /// @notice the Wit/oracle blockchain. 
    /// @dev The extra fee gets calculated in proportion to:
    /// @param _evmGasPrice Tentative EVM gas price at the moment the query result is ready.
    /// @param _evmWitPrice Tentative nanoWit price in Wei at the moment the query is solved on the Wit/oracle blockchain.
    /// @param _querySLA The query SLA data security parameters as required for the Wit/oracle blockchain. 
    function estimateExtraFee(
            uint256 _evmGasPrice, 
            uint256 _evmWitPrice, 
            Witnet.RadonSLA memory _querySLA
        )
        public view
        virtual override
        returns (uint256)
    {
        return (
            _evmWitPrice * ((3 + _querySLA.witNumWitnesses) * _querySLA.witUnitaryReward)
                + (_querySLA.maxTallyResultSize > 32
                    ? _evmGasPrice * __sstoreFromZeroGas * ((_querySLA.maxTallyResultSize - 32) / 32)
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
        returns (uint256)
    {
        return __storage().queries[_queryId].request.evmReward;
    }

    /// @notice Retrieves the RAD hash and SLA parameters of the given query.
    /// @param _queryId The unique query identifier.
    function getQueryRequest(uint256 _queryId)
        external view 
        override
        returns (Witnet.QueryRequest memory)
    {
        return WitOracleDataLib.seekQueryRequest(_queryId);
    }

    /// Retrieves the Witnet-provable result, and metadata, to a previously posted request.    
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier
    function getQueryResponse(uint256 _queryId)
        public view
        virtual override
        returns (Witnet.QueryResponse memory)
    {
        return WitOracleDataLib.seekQueryResponse(_queryId);
    }

    function getQueryResponseStatusTag(uint256 _queryId)
        virtual override
        external view
        returns (string memory)
    {
        return WitOracleDataLib.toString(
            getQueryResponseStatus(_queryId)
        );
    }

    /// @notice Retrieves the CBOR-encoded buffer containing the Witnet-provided result to the given query.
    /// @param _queryId The unique query identifier.
    function getQueryResultCborBytes(uint256 _queryId) 
        external view 
        virtual override
        returns (bytes memory)
    {
        return WitOracleDataLib.seekQueryResponse(_queryId).resultCborBytes;
    }

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param _queryId The unique query identifier.
    function getQueryResultError(uint256 _queryId)
        virtual override 
        public view
        returns (Witnet.ResultError memory)
    {
        Witnet.QueryResponseStatus _status = getQueryResponseStatus(_queryId);
        try WitOracleResultErrorsLib.asResultError(_status, WitOracleDataLib.seekQueryResponse(_queryId).resultCborBytes)
            returns (Witnet.ResultError memory _resultError)
        {
            return _resultError;
        } 
        catch Error(string memory _reason) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: string(abi.encodePacked("WitOracleResultErrorsLib: ", _reason))
            });
        }
        catch (bytes memory) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitOracleResultErrorsLib: assertion failed"
            });
        }
    }

    function getQueryStatusTag(uint256 _queryId)
        virtual override
        external view
        returns (string memory)
    {
        return WitOracleDataLib.toString(
            getQueryStatus(_queryId)
        );
    }

    function getQueryStatusBatch(uint256[] calldata _queryIds)
        virtual override
        external view
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
        returns (uint256)
    {
        return __storage().nonce + 1;
    }

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and 
    /// @notice solved by the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be 
    /// @notice transferred to the reporter who relays back the Witnet-provable result to this request.
    /// @dev Reasons to fail:
    /// @dev - the RAD hash was not previously verified by the WitOracleRadonRegistry registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param _queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @return _queryId Unique query identifier.
    function postQuery(
            bytes32 _queryRAD, 
            Witnet.RadonSLA memory _querySLA
        )
        virtual override
        public payable
        checkReward(
            _getMsgValue(),
            estimateBaseFee(_getGasPrice(), _queryRAD)
        )
        checkSLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __postQuery(
            _getMsgSender(), 
            0,
            uint72(_getMsgValue()),
            _queryRAD, 
            _querySLA
            
        );
        // Let Web3 observers know that a new request has been posted
        emit WitOracleQuery(
            _getMsgSender(),
            _getGasPrice(),
            _getMsgValue(),
            _queryId, 
            _queryRAD,
            _querySLA
        );
    }
   
    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, an `WitOracleQueryResponseDeliveryFailed`
    /// @notice will be triggered, and the Witnet audit trail will be saved in storage, but not so the actual CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitOracleConsumer interface;
    /// @dev - the RAD hash was not previously verified by the WitOracleRadonRegistry registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - zero callback gas limit is provided;
    /// @dev - insufficient value is paid as reward.
    /// @param _queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param _queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    function postQueryWithCallback(
            bytes32 _queryRAD, 
            Witnet.RadonSLA memory _querySLA,
            uint24 _queryCallbackGasLimit
        )
        virtual override public payable 
        returns (uint256)
    {
        return postQueryWithCallback(
            IWitOracleConsumer(_getMsgSender()),
            _queryRAD,
            _querySLA,
            _queryCallbackGasLimit
        );
    }

    function postQueryWithCallback(
            IWitOracleConsumer _consumer,
            bytes32 _queryRAD,
            Witnet.RadonSLA memory _querySLA,
            uint24 _queryCallbackGasLimit
        )
        virtual override public payable
        checkCallbackRecipient(_consumer, _queryCallbackGasLimit)
        checkReward(
            _getMsgValue(),
            estimateBaseFeeWithCallback(
                _getGasPrice(),  
                _queryCallbackGasLimit
            )
        )
        checkSLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __postQuery(
            address(_consumer),
            _queryCallbackGasLimit,
            uint72(_getMsgValue()),
            _queryRAD,
            _querySLA
        );
        emit WitOracleQuery(
            _getMsgSender(),
            _getGasPrice(),
            _getMsgValue(),
            _queryId,
            _queryRAD,
            _querySLA
        );
    }

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, a `WitOracleQueryResponseDeliveryFailed`
    /// @notice event will be triggered, and the Witnet audit trail will be saved in storage, but not so the CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitOracleConsumer interface;
    /// @dev - the provided bytecode is empty;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - zero callback gas limit is provided;
    /// @dev - insufficient value is paid as reward.
    /// @param _queryUnverifiedBytecode The (unverified) bytecode containing the actual data request to be solved by the Witnet blockchain.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param _queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    function postQueryWithCallback(
            bytes calldata _queryUnverifiedBytecode,
            Witnet.RadonSLA memory _querySLA,
            uint24 _queryCallbackGasLimit
        )
        virtual override public payable
        returns (uint256)
    {
        return postQueryWithCallback(
            IWitOracleConsumer(_getMsgSender()),
            _queryUnverifiedBytecode,
            _querySLA,
            _queryCallbackGasLimit
        );
    }

    function postQueryWithCallback(
            IWitOracleConsumer _consumer,
            bytes calldata _queryUnverifiedBytecode,
            Witnet.RadonSLA memory _querySLA, 
            uint24 _queryCallbackGasLimit
        )
        virtual override public payable 
        checkCallbackRecipient(_consumer, _queryCallbackGasLimit)
        checkReward(
            _getMsgValue(),
            estimateBaseFeeWithCallback(
                _getGasPrice(),
                _queryCallbackGasLimit
            )
        )
        checkSLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __postQuery(
            address(_consumer),
            _queryCallbackGasLimit,
            uint72(_getMsgValue()),
            bytes32(0),
            _querySLA
        );
        WitOracleDataLib.seekQueryRequest(_queryId).radonBytecode = _queryUnverifiedBytecode;
        emit WitOracleQuery(
            _getMsgSender(),
            _getGasPrice(),
            _getMsgValue(),
            _queryId,
            _queryUnverifiedBytecode,
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
        Witnet.QueryRequest storage __request = WitOracleDataLib.seekQueryRequest(_queryId);
        __request.evmReward += uint72(_getMsgValue());
        emit WitOracleQueryUpgrade(
            _queryId,
            _getMsgSender(),
            _getGasPrice(),
            __request.evmReward
        );
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
        return postQuery(
            _queryRadHash,
            Witnet.RadonSLA({
                witNumWitnesses: _querySLA.witNumWitnesses,
                witUnitaryReward: _querySLA.witUnitaryReward,
                maxTallyResultSize: 32
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
    // --- Internal functions -----------------------------------------------------------------------------------------

    function __postQuery(
            address _requester,
            uint24 _evmCallbackGasLimit,
            uint72 _evmReward,
            bytes32 _radHash, 
            Witnet.RadonSLA memory _sla
        )
        virtual internal
        returns (uint256 _queryId)
    {
        _queryId = ++ __storage().nonce;
        Witnet.QueryRequest storage __request = WitOracleDataLib.seekQueryRequest(_queryId);
        _require(__request.requester == address(0), "already posted");
        {
            __request.requester = _requester;
            __request.gasCallback = _evmCallbackGasLimit;
            __request.evmReward = _evmReward;
            __request.radonRadHash = _radHash;
            __request.radonSLA = _sla;
        }
    }

    /// Returns storage pointer to contents of 'WitOracleDataLib.Storage' struct.
    function __storage() virtual internal pure returns (WitOracleDataLib.Storage storage _ptr) {
      return WitOracleDataLib.data();
    }

    function _revertWitOracleDataLibUnhandledException() internal view {
        _revert(_revertWitOracleDataLibUnhandledExceptionReason());
    }

    function _revertWitOracleDataLibUnhandledExceptionReason() internal pure returns (string memory) {
        return string(abi.encodePacked(
            type(WitOracleDataLib).name,
            ": unhandled assertion"
        ));
    }
}
