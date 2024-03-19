// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetUpgradableBase.sol";
import "../../WitnetOracle.sol";
import "../../WitnetRequestFactory.sol";
import "../../data/WitnetOracleDataLib.sol";
import "../../interfaces/IWitnetOracleReporter.sol";
import "../../interfaces/IWitnetRequestBoardAdminACLs.sol";
import "../../interfaces/IWitnetConsumer.sol";
import "../../libs/WitnetErrorsLib.sol";
import "../../patterns/Payable.sol";

/// @title Witnet Request Board "trustable" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitnetOracleTrustableBase
    is 
        WitnetUpgradableBase,
        WitnetOracle,
        IWitnetOracleReporter,
        IWitnetRequestBoardAdminACLs,
        Payable 
{
    using Witnet for bytes;
    using Witnet for Witnet.Result;
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetV2 for WitnetV2.RadonSLA;
    using WitnetV2 for WitnetV2.Request;
    using WitnetV2 for WitnetV2.Response;

    bytes4 public immutable override specs = type(IWitnetOracle).interfaceId;
    WitnetRequestBytecodes immutable public override registry;
    
    WitnetRequestFactory immutable private __factory;

    modifier checkCallbackRecipient(address _addr, uint24 _callbackGasLimit) {
        require(
            _addr.code.length > 0 && IWitnetConsumer(_addr).reportableFrom(address(this)) && _callbackGasLimit > 0,
            "WitnetOracle: invalid callback"
        ); _;
    }

    modifier checkReward(uint256 _baseFee) {
        require(
            _getMsgValue() >= _baseFee, 
            "WitnetOracle: insufficient reward"
        ); 
        require(
            _getMsgValue() <= _baseFee * 10,
            "WitnetOracle: too much reward"
        );
        _;
    }

    modifier checkSLA(WitnetV2.RadonSLA calldata sla) {
        require(
            WitnetV2.isValid(sla), 
            "WitnetOracle: invalid SLA"
        ); _;
    }

    /// Asserts the given query is currently in the given status.
    modifier inStatus(uint256 _queryId, WitnetV2.QueryStatus _status) {
      if (WitnetOracleDataLib.seekQueryStatus(_queryId) != _status) {
        revert(WitnetOracleDataLib.notInStatusRevertMessage(_status));
      } else {
        _;
      }
    }

    /// Asserts the caller actually posted the referred query.
    modifier onlyRequester(uint256 _queryId) {
        require(
            msg.sender == WitnetOracleDataLib.seekQueryRequest(_queryId).requester, 
            "WitnetOracle: not the requester"
        ); _;
    }

    /// Asserts the caller is authorized as a reporter
    modifier onlyReporters {
        require(
            __storage().reporters[msg.sender],
            "WitnetOracle: unauthorized reporter"
        );
        _;
    } 
    
    constructor(
            WitnetRequestFactory _factory,
            WitnetRequestBytecodes _registry,
            bool _upgradable,
            bytes32 _versionTag,
            address _currency
        )
        Ownable(address(msg.sender))
        Payable(_currency)
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.board"
        )
    {
        __factory = _factory;
        registry = _registry;
    }

    receive() external payable { 
        revert("WitnetOracle: no transfers accepted");
    }

    /// @dev Provide backwards compatibility for dapps bound to versions <= 0.6.1
    /// @dev (i.e. calling methods in IWitnetOracle)
    /// @dev (Until 'function ... abi(...)' modifier is allegedly supported in solc versions >= 0.9.1)
    /* solhint-disable payable-fallback */
    /* solhint-disable no-complex-fallback */
    fallback() override external { 
        revert(string(abi.encodePacked(
            "WitnetOracle: not implemented: 0x",
            Witnet.toHexString(uint8(bytes1(msg.sig))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 8))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 16))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 24)))
        )));
    }

    function channel() virtual override public view returns (bytes4) {
        return bytes4(keccak256(abi.encode(address(this), block.chainid)));
    }

    function factory() virtual override public view returns (WitnetRequestFactory) {
        return __factory;
    }

    
    // ================================================================================================================
    // --- Yet to be implemented virtual methods ----------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function estimateBaseFee(uint256 _gasPrice, uint16 _resultMaxSize) virtual public view returns (uint256); 

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _gasPrice, uint24 _callbackGasLimit) virtual public view returns (uint256);

    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData)
        public
        override
    {
        address _owner = owner();
        address[] memory _newReporters;

        if (_owner == address(0)) {
            // get owner (and reporters) from _initData
            bytes memory _newReportersRaw;
            (_owner, _newReportersRaw) = abi.decode(_initData, (address, bytes));
            _transferOwnership(_owner);
            _newReporters = abi.decode(_newReportersRaw, (address[]));
        } else {
            // only owner can initialize:
            require(
                msg.sender == _owner,
                "WitnetOracle: not the owner"
            );
            // get reporters from _initData
            _newReporters = abi.decode(_initData, (address[]));
        }

        if (
            __proxiable().codehash != bytes32(0)
                && __proxiable().codehash == codehash()
        ) {
            revert("WitnetOracle: already upgraded");
        }
        __proxiable().codehash = codehash();

        require(
            address(__factory).code.length > 0,
            "WitnetOracle: inexistent factory"
        );
        require(
            __factory.specs() == type(IWitnetRequestFactory).interfaceId, 
            "WitnetOracle: uncompliant factory"
        );
        require(
            address(__factory.witnet()) == address(this) 
                && address(__factory.registry()) == address(registry),
            "WitnetOracle: discordant factory"
        );

        // Set reporters, if any
        __setReporters(_newReporters);

        emit Upgraded(_owner, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && owner() == _from
        );
    }


    // ================================================================================================================
    // --- Partial implementation of IWitnetOracle --------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `resultMaxSize`. 
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param radHash The hash of some Witnet Data Request previously posted in the WitnetRequestBytecodes registry.
    function estimateBaseFee(uint256 gasPrice, bytes32 radHash)
        public view
        virtual override
        returns (uint256)
    {
        uint16 _resultMaxSize = registry.lookupRadonRequestResultMaxSize(radHash);
        require(
            _resultMaxSize > 0, 
            "WitnetOracleTrustableDefault: invalid RAD"
        );
        return estimateBaseFee(
            gasPrice,
            _resultMaxSize
        );
    }

    /// Retrieves copy of all response data related to a previously posted request, removing the whole query from storage.
    /// @dev Fails if the `_witnetQueryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _witnetQueryId The unique query identifier.
    function fetchQueryResponse(uint256 _witnetQueryId)
        virtual override
        external
        inStatus(_witnetQueryId, WitnetV2.QueryStatus.Finalized)
        onlyRequester(_witnetQueryId)
        returns (WitnetV2.Response memory _response)
    {
        _response = WitnetOracleDataLib.seekQuery(_witnetQueryId).response;
        delete __storage().queries[_witnetQueryId];
    }

    /// Gets the whole Query data contents, if any, no matter its current status.
    function getQuery(uint256 _witnetQueryId)
      public view
      virtual override
      returns (WitnetV2.Query memory)
    {
        return __storage().queries[_witnetQueryId];
    }

    /// @notice Gets current EVM reward the report can claim, if not done yet.
    function getQueryEvmReward(uint256 _witnetQueryId) 
        external view 
        virtual override
        returns (uint256)
    {
        return __storage().queries[_witnetQueryId].request.evmReward;
    }


    
    /// @notice Retrieves the RAD hash and SLA parameters of the given query.
    /// @param _witnetQueryId The unique query identifier.
    function getQueryRequest(uint256 _witnetQueryId)
        external view 
        override
        returns (WitnetV2.Request memory)
    {
        return WitnetOracleDataLib.seekQueryRequest(_witnetQueryId);
    }

    /// Retrieves the Witnet-provable result, and metadata, to a previously posted request.    
    /// @dev Fails if the `_witnetQueryId` is not in 'Reported' status.
    /// @param _witnetQueryId The unique query identifier
    function getQueryResponse(uint256 _witnetQueryId)
        public view
        virtual override
        returns (WitnetV2.Response memory _response)
    {
        return WitnetOracleDataLib.seekQueryResponse(_witnetQueryId);
    }

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query has been succesfully solved;
    /// @notice   - 3 => Error: the query couldn't get solved due to some issue.
    /// @param _witnetQueryId The unique query identifier.
    function getQueryResponseStatus(uint256 _witnetQueryId)
        virtual override public view
        returns (WitnetV2.ResponseStatus)
    {
        return WitnetOracleDataLib.seekQueryResponseStatus(_witnetQueryId);
    }

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param _witnetQueryId The unique query identifier.
    function getQueryResultError(uint256 _witnetQueryId)
        virtual override 
        public view
        returns (Witnet.ResultError memory)
    {
        WitnetV2.ResponseStatus _status = WitnetOracleDataLib.seekQueryResponseStatus(_witnetQueryId);
        try WitnetErrorsLib.asResultError(_status, WitnetOracleDataLib.seekQueryResponse(_witnetQueryId).resultCborBytes)
            returns (Witnet.ResultError memory _resultError)
        {
            return _resultError;
        } 
        catch Error(string memory _reason) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: string(abi.encodePacked("WitnetErrorsLib: ", _reason))
            });
        }
        catch (bytes memory) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetErrorsLib: assertion failed"
            });
        }
    }

    /// Gets current status of given query.
    function getQueryStatus(uint256 _witnetQueryId)
        external view
        override
        returns (WitnetV2.QueryStatus)
    {
        return WitnetOracleDataLib.seekQueryStatus(_witnetQueryId);
    }

    function getQueryStatusBatch(uint256[] calldata _witnetQueryIds)
        external view
        override
        returns (WitnetV2.QueryStatus[] memory _status)
    {
        _status = new WitnetV2.QueryStatus[](_witnetQueryIds.length);
        for (uint _ix = 0; _ix < _witnetQueryIds.length; _ix ++) {
            _status[_ix] = WitnetOracleDataLib.seekQueryStatus(_witnetQueryIds[_ix]);
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
    /// @dev - the RAD hash was not previously verified by the WitnetRequestBytecodes registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param _queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @return _witnetQueryId Unique query identifier.
    function postRequest(
            bytes32 _queryRAD, 
            WitnetV2.RadonSLA calldata _querySLA
        )
        virtual override
        external payable
        checkReward(estimateBaseFee(_getGasPrice(), _queryRAD))
        checkSLA(_querySLA)
        returns (uint256 _witnetQueryId)
    {
        _witnetQueryId = __postRequest(_queryRAD, _querySLA, 0);
        // Let Web3 observers know that a new request has been posted
        emit WitnetQuery(
            _witnetQueryId, 
            _getMsgValue(),
            _querySLA
        );
    }
   
    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, an `WitnetQueryResponseDeliveryFailed`
    /// @notice will be triggered, and the Witnet audit trail will be saved in storage, but not so the actual CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitnetConsumer interface;
    /// @dev - the RAD hash was not previously verified by the WitnetRequestBytecodes registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - zero callback gas limit is provided;
    /// @dev - insufficient value is paid as reward.
    /// @param _queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param _queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    /// @return _witnetQueryId Unique query identifier.
    function postRequestWithCallback(
            bytes32 _queryRAD, 
            WitnetV2.RadonSLA calldata _querySLA,
            uint24 _queryCallbackGasLimit
        )
        virtual override
        external payable 
        checkCallbackRecipient(msg.sender, _queryCallbackGasLimit)
        checkReward(estimateBaseFeeWithCallback(_getGasPrice(),  _queryCallbackGasLimit))
        checkSLA(_querySLA)
        returns (uint256 _witnetQueryId)
    {
        _witnetQueryId = __postRequest(
            _queryRAD,
            _querySLA,
            _queryCallbackGasLimit
        );
        emit WitnetQuery(
            _witnetQueryId, 
            _getMsgValue(),
            _querySLA
        );
    }

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, a `WitnetQueryResponseDeliveryFailed`
    /// @notice event will be triggered, and the Witnet audit trail will be saved in storage, but not so the CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitnetConsumer interface;
    /// @dev - the provided bytecode is empty;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - zero callback gas limit is provided;
    /// @dev - insufficient value is paid as reward.
    /// @param _queryUnverifiedBytecode The (unverified) bytecode containing the actual data request to be solved by the Witnet blockchain.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param _queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    /// @return _witnetQueryId Unique query identifier.
    function postRequestWithCallback(
            bytes calldata _queryUnverifiedBytecode,
            WitnetV2.RadonSLA calldata _querySLA, 
            uint24 _queryCallbackGasLimit
        )
        virtual override
        external payable 
        checkCallbackRecipient(msg.sender, _queryCallbackGasLimit)
        checkReward(estimateBaseFeeWithCallback(_getGasPrice(),  _queryCallbackGasLimit))
        checkSLA(_querySLA)
        returns (uint256 _witnetQueryId)
    {
        _witnetQueryId = __postRequest(
            bytes32(0),
            _querySLA,
            _queryCallbackGasLimit
        );
        WitnetOracleDataLib.seekQueryRequest(_witnetQueryId).witnetBytecode = _queryUnverifiedBytecode;
        emit WitnetQuery(
            _witnetQueryId,
            _getMsgValue(),
            _querySLA
        );
    }
  
    /// Increments the reward of a previously posted request by adding the transaction value to it.
    /// @dev Fails if the `_witnetQueryId` is not in 'Posted' status.
    /// @param _witnetQueryId The unique query identifier.
    function upgradeQueryEvmReward(uint256 _witnetQueryId)
        external payable
        virtual override      
        inStatus(_witnetQueryId, WitnetV2.QueryStatus.Posted)
    {
        WitnetV2.Request storage __request = WitnetOracleDataLib.seekQueryRequest(_witnetQueryId);
        __request.evmReward += uint72(_getMsgValue());
        emit WitnetQueryRewardUpgraded(_witnetQueryId, __request.evmReward);
    }

    
    // ================================================================================================================
    // --- Full implementation of IWitnetOracleReporter ---------------------------------------------------------

    /// @notice Estimates the actual earnings (or loss), in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    function estimateReportEarnings(
            uint256[] calldata _witnetQueryIds, 
            bytes calldata,
            uint256 _txGasPrice,
            uint256 _nanoWitPrice
        )
        external view
        virtual override
        returns (uint256 _revenues, uint256 _expenses)
    {
        for (uint _ix = 0; _ix < _witnetQueryIds.length; _ix ++) {
            if (WitnetOracleDataLib.seekQueryStatus(_witnetQueryIds[_ix]) == WitnetV2.QueryStatus.Posted) {
                WitnetV2.Request storage __request = WitnetOracleDataLib.seekQueryRequest(_witnetQueryIds[_ix]);
                _revenues += __request.evmReward;
                if (__request.gasCallback > 0) {
                    _expenses += estimateBaseFeeWithCallback(_txGasPrice, __request.gasCallback);
                } else {
                    if (__request.witnetRAD != bytes32(0)) {
                        _expenses += estimateBaseFee(_txGasPrice, __request.witnetRAD);
                    } else {
                        // todo: improve profit estimation accuracy if reporting on deleted query
                        _expenses += estimateBaseFee(_txGasPrice, uint16(0)); 
                    }
                }
                _expenses +=  __request.witnetSLA.nanoWitTotalFee() * _nanoWitPrice;
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
        return WitnetOracleDataLib.extractWitnetDataRequests(registry, _queryIds);
    }

    /// Reports the Witnet-provable result to a previously posted request. 
    /// @dev Will assume `block.timestamp` as the timestamp at which the request was solved.
    /// @dev Fails if:
    /// @dev - the `_witnetQueryId` is not in 'Posted' status.
    /// @dev - provided `_witnetQueryResultTallyHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param _witnetQueryId The unique identifier of the data request.
    /// @param _witnetQueryResultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _witnetQueryResultCborBytes The result itself as bytes.
    function reportResult(
            uint256 _witnetQueryId,
            bytes32 _witnetQueryResultTallyHash,
            bytes calldata _witnetQueryResultCborBytes
        )
        external override
        onlyReporters
        inStatus(_witnetQueryId, WitnetV2.QueryStatus.Posted)
        returns (uint256)
    {
        // results cannot be empty:
        require(
            _witnetQueryResultCborBytes.length != 0, 
            "WitnetOracleTrustableDefault: result cannot be empty"
        );
        // do actual report and return reward transfered to the reproter:
        // solhint-disable not-rely-on-time
        return __reportResultAndReward(
            _witnetQueryId,
            uint32(block.timestamp),
            _witnetQueryResultTallyHash,
            _witnetQueryResultCborBytes
        );
    }

    /// Reports the Witnet-provable result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_witnetQueryId` is not in 'Posted' status.
    /// @dev - provided `_witnetQueryResultTallyHash` is zero;
    /// @dev - length of provided `_witnetQueryResultCborBytes` is zero.
    /// @param _witnetQueryId The unique query identifier
    /// @param _witnetQueryResultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param _witnetQueryResultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _witnetQueryResultCborBytes The result itself as bytes.
    function reportResult(
            uint256 _witnetQueryId,
            uint32  _witnetQueryResultTimestamp,
            bytes32 _witnetQueryResultTallyHash,
            bytes calldata _witnetQueryResultCborBytes
        )
        external
        override
        onlyReporters
        inStatus(_witnetQueryId, WitnetV2.QueryStatus.Posted)
        returns (uint256)
    {
        // validate timestamp
        require(
            _witnetQueryResultTimestamp > 0 
                && _witnetQueryResultTimestamp <= block.timestamp, 
            "WitnetOracleTrustableDefault: bad timestamp"
        );
        // results cannot be empty
        require(
            _witnetQueryResultCborBytes.length != 0, 
            "WitnetOracleTrustableDefault: result cannot be empty"
        );
        // do actual report and return reward transfered to the reproter:
        return  __reportResultAndReward(
            _witnetQueryId,
            _witnetQueryResultTimestamp,
            _witnetQueryResultTallyHash,
            _witnetQueryResultCborBytes
        );
    }

    /// @notice Reports Witnet-provided results to multiple requests within a single EVM tx.
    /// @notice Emits either a WitnetQueryResponse* or a BatchReportError event per batched report.
    /// @dev Fails only if called from unauthorized address.
    /// @param _batchResults Array of BatchResult structs, every one containing:
    ///         - unique query identifier;
    ///         - timestamp of the solving tally txs in Witnet. If zero is provided, EVM-timestamp will be used instead;
    ///         - hash of the corresponding data request tx at the Witnet side-chain level;
    ///         - data request result in raw bytes.
    function reportResultBatch(IWitnetOracleReporter.BatchResult[] calldata _batchResults)
        external override
        onlyReporters
        returns (uint256 _batchReward)
    {
        for ( uint _i = 0; _i < _batchResults.length; _i ++) {
            if (
                WitnetOracleDataLib.seekQueryStatus(_batchResults[_i].queryId)
                    != WitnetV2.QueryStatus.Posted
            ) {
                emit BatchReportError(
                    _batchResults[_i].queryId,
                    WitnetOracleDataLib.notInStatusRevertMessage(WitnetV2.QueryStatus.Posted)
                );
            } else if (
                uint256(_batchResults[_i].queryResultTimestamp) > block.timestamp
                    || _batchResults[_i].queryResultTimestamp == 0
                    || _batchResults[_i].queryResultCborBytes.length == 0
            ) {
                emit BatchReportError(
                    _batchResults[_i].queryId, 
                    "WitnetOracle: invalid report data"
                );
            } else {
                _batchReward += __reportResult(
                    _batchResults[_i].queryId,
                    _batchResults[_i].queryResultTimestamp,
                    _batchResults[_i].queryResultTallyHash,
                    _batchResults[_i].queryResultCborBytes
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


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardAdminACLs' ------------------------------------------------------

    /// Tells whether given address is included in the active reporters control list.
    /// @param _reporter The address to be checked.
    function isReporter(address _reporter) public view override returns (bool) {
        return WitnetOracleDataLib.isReporter(_reporter);
    }

    /// Adds given addresses to the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersSet` event. 
    /// @param _reporters List of addresses to be added to the active reporters control list.
    function setReporters(address[] memory _reporters)
        public
        override
        onlyOwner
    {
        __setReporters(_reporters);
    }

    /// Removes given addresses from the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersUnset` event. 
    /// @param _exReporters List of addresses to be added to the active reporters control list.
    function unsetReporters(address[] memory _exReporters)
        public
        override
        onlyOwner
    {
        for (uint ix = 0; ix < _exReporters.length; ix ++) {
            address _reporter = _exReporters[ix];
            __storage().reporters[_reporter] = false;
        }
        emit ReportersUnset(_exReporters);
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function __newQueryId(bytes32 _queryRAD, bytes32 _querySLA)
        virtual internal view
        returns (uint256)
    {
        return uint(keccak256(abi.encode(
            channel(),
            block.number,
            msg.sender,
            _queryRAD,
            _querySLA
        )));
    }

    function __postRequest(bytes32 _radHash, WitnetV2.RadonSLA calldata _sla, uint24 _callbackGasLimit)
        virtual internal
        returns (uint256 _witnetQueryId)
    {
        _witnetQueryId = ++ __storage().nonce; //__newQueryId(_radHash, _packedSLA);
        WitnetV2.Request storage __request = WitnetOracleDataLib.seekQueryRequest(_witnetQueryId);
        require(__request.requester == address(0), "WitnetOracle: already posted");
        {
            __request.requester = msg.sender;
            __request.gasCallback = _callbackGasLimit;
            __request.evmReward = uint72(_getMsgValue());
            __request.witnetRAD = _radHash;
            __request.witnetSLA = _sla;
        }
    }

    function __reportResult(
            uint256 _witnetQueryId,
            uint32  _witnetQueryResultTimestamp,
            bytes32 _witnetQueryResultTallyHash,
            bytes calldata _witnetQueryResultCborBytes
        )
        virtual internal
        returns (uint256 _evmReward)
    {
        // read requester address and whether a callback was requested:
        WitnetV2.Request storage __request = WitnetOracleDataLib.seekQueryRequest(_witnetQueryId);
                
        // read query EVM reward:
        _evmReward = __request.evmReward;
        
        // set EVM reward right now as to avoid re-entrancy attacks:
        __request.evmReward = 0; 

        // determine whether a callback is required
        if (__request.gasCallback > 0) {
            (
                uint256 _evmCallbackActualGas,
                bool _evmCallbackSuccess,
                string memory _evmCallbackRevertMessage
            ) = __reportResultCallback(
                _witnetQueryId,
                _witnetQueryResultTimestamp,
                _witnetQueryResultTallyHash,
                _witnetQueryResultCborBytes,
                __request.requester,
                __request.gasCallback
            );
            if (_evmCallbackSuccess) {
                // => the callback run successfully
                emit WitnetQueryResponseDelivered(
                    _witnetQueryId,
                    _getGasPrice(),
                    _evmCallbackActualGas
                );
            } else {
                // => the callback reverted
                emit WitnetQueryResponseDeliveryFailed(
                    _witnetQueryId,
                    _witnetQueryResultCborBytes,
                    _getGasPrice(),
                    _evmCallbackActualGas,
                    bytes(_evmCallbackRevertMessage).length > 0 
                        ? _evmCallbackRevertMessage
                        : "WitnetOracle: callback exceeded gas limit"
                );
            }
            // upon delivery, successfull or not, the audit trail is saved into storage, 
            // but not the actual result which was intended to be passed over to the requester:
            __writeQueryResponse(
                _witnetQueryId, 
                _witnetQueryResultTimestamp, 
                _witnetQueryResultTallyHash, 
                hex""
            );
        } else {
            // => no callback is involved
            emit WitnetQueryResponse(
                _witnetQueryId, 
                _getGasPrice()
            );
            // write query result and audit trail data into storage 
            __writeQueryResponse(
                _witnetQueryId,
                _witnetQueryResultTimestamp,
                _witnetQueryResultTallyHash,
                _witnetQueryResultCborBytes
            );
        }
    }

    function __reportResultAndReward(
            uint256 _witnetQueryId,
            uint32  _witnetQueryResultTimestamp,
            bytes32 _witnetQueryResultTallyHash,
            bytes calldata _witnetQueryResultCborBytes
        )
        virtual internal
        returns (uint256 _evmReward)
    {
        _evmReward = __reportResult(
            _witnetQueryId, 
            _witnetQueryResultTimestamp, 
            _witnetQueryResultTallyHash, 
            _witnetQueryResultCborBytes
        );
        // transfer reward to reporter
        __safeTransferTo(
            payable(msg.sender),
            _evmReward
        );
    }

    function __reportResultCallback(
            uint256 _witnetQueryId,
            uint64  _witnetQueryResultTimestamp,
            bytes32 _witnetQueryResultTallyHash,
            bytes calldata _witnetQueryResultCborBytes,
            address _evmRequester,
            uint256 _evmCallbackGasLimit
        )
        virtual internal
        returns (
            uint256 _evmCallbackActualGas, 
            bool _evmCallbackSuccess, 
            string memory _evmCallbackRevertMessage
        )
    {
        _evmCallbackActualGas = gasleft();
        if (_witnetQueryResultCborBytes[0] == bytes1(0xd8)) {
            WitnetCBOR.CBOR[] memory _errors = WitnetCBOR.fromBytes(_witnetQueryResultCborBytes).readArray();
            if (_errors.length < 2) {
                // try to report result with unknown error:
                try IWitnetConsumer(_evmRequester).reportWitnetQueryError{gas: _evmCallbackGasLimit}(
                    _witnetQueryId,
                    _witnetQueryResultTimestamp,
                    _witnetQueryResultTallyHash,
                    block.number,
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
                    _evmCallbackSuccess = true;
                } catch Error(string memory err) {
                    _evmCallbackRevertMessage = err;
                }
            } else {
                // try to report result with parsable error:
                try IWitnetConsumer(_evmRequester).reportWitnetQueryError{gas: _evmCallbackGasLimit}(
                    _witnetQueryId,
                    _witnetQueryResultTimestamp,
                    _witnetQueryResultTallyHash,
                    block.number,
                    Witnet.ResultErrorCodes(_errors[0].readUint()),
                    _errors[0]
                ) {
                    _evmCallbackSuccess = true;
                } catch Error(string memory err) {
                    _evmCallbackRevertMessage = err; 
                }
            }
        } else {
            // try to report result result with no error :
            try IWitnetConsumer(_evmRequester).reportWitnetQueryResult{gas: _evmCallbackGasLimit}(
                _witnetQueryId,
                _witnetQueryResultTimestamp,
                _witnetQueryResultTallyHash,
                block.number,
                WitnetCBOR.fromBytes(_witnetQueryResultCborBytes)
            ) {
                _evmCallbackSuccess = true;
            } catch Error(string memory err) {
                _evmCallbackRevertMessage = err;
            } catch (bytes memory) {}
        }
        _evmCallbackActualGas -= gasleft();
    }

    function __setReporters(address[] memory _reporters)
        virtual internal
    {
        for (uint ix = 0; ix < _reporters.length; ix ++) {
            address _reporter = _reporters[ix];
            __storage().reporters[_reporter] = true;
        }
        emit ReportersSet(_reporters);
    }

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function __storage() virtual internal pure returns (WitnetOracleDataLib.Storage storage _ptr) {
      return WitnetOracleDataLib.data();
    }

    function __writeQueryResponse(
            uint256 _witnetQueryId, 
            uint32  _witnetQueryResultTimestamp, 
            bytes32 _witnetQueryResultTallyHash, 
            bytes memory _witnetQueryResultCborBytes
        )
        virtual internal
    {
        WitnetOracleDataLib.seekQuery(_witnetQueryId).response = WitnetV2.Response({
            reporter: msg.sender,
            finality: uint64(block.number),
            resultTimestamp: _witnetQueryResultTimestamp,
            resultTallyHash: _witnetQueryResultTallyHash,
            resultCborBytes: _witnetQueryResultCborBytes
        });
    }

}