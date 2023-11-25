// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetUpgradableBase.sol";
import "../../WitnetRequestBoard.sol";
import "../../WitnetRequestFactory.sol";

import "../../data/WitnetRequestBoardDataACLs.sol";
import "../../interfaces/IWitnetRequest.sol";
import "../../interfaces/IWitnetRequestBoardAdminACLs.sol";
import "../../interfaces/IWitnetRequestBoardReporter.sol";
import "../../interfaces/V2/IWitnetConsumer.sol";
import "../../libs/WitnetErrorsLib.sol";
import "../../patterns/Payable.sol";

/// @title Witnet Request Board "trustable" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitnetRequestBoardTrustableBase
    is 
        WitnetUpgradableBase,
        WitnetRequestBoard,
        WitnetRequestBoardDataACLs,
        IWitnetRequestBoardReporter,
        IWitnetRequestBoardAdminACLs,
        Payable 
{
    using Witnet for bytes;
    using Witnet for Witnet.Result;
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetV2 for WitnetV2.RadonSLA;

    bytes4 public immutable override specs = type(IWitnetRequestBoard).interfaceId;
    WitnetRequestFactory immutable public override factory;

    modifier checkCallbackRecipient(address _addr) {
        require(
            _addr.code.length > 0 && IWitnetConsumer(_addr).reportableFrom(address(this)),
            "WitnetRequestBoardTrustableBase: invalid callback recipient"
        ); _;
    }

    modifier checkReward(uint256 _baseFee) {
        require(
            _getMsgValue() >= _baseFee, 
            "WitnetRequestBoardTrustableBase: reward too low"
        ); _;
    }

    modifier checkSLA(WitnetV2.RadonSLA calldata sla) {
        require(
            WitnetV2.isValid(sla), 
            "WitnetRequestBoardTrustableBase: invalid SLA"
        ); _;
    }
    
    constructor(
            WitnetRequestFactory _factory,
            bool _upgradable,
            bytes32 _versionTag,
            address _currency
        )
        Payable(_currency)
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.board"
        )
    {
        assert(address(_factory) != address(0));
        factory = _factory;
    }

    function registry() public view virtual override returns (WitnetBytecodes) {
        return factory.registry();
    }

    receive() external payable { 
        revert("WitnetRequestBoardTrustableBase: no transfers accepted");
    }

    /// @dev Provide backwards compatibility for dapps bound to versions <= 0.6.1
    /// @dev (i.e. calling methods in IWitnetRequestBoard)
    /// @dev (Until 'function ... abi(...)' modifier is allegedly supported in solc versions >= 0.9.1)
    /* solhint-disable payable-fallback */
    /* solhint-disable no-complex-fallback */
    fallback() override external { 
        revert(string(abi.encodePacked(
            "WitnetRequestBoardTrustableBase: not implemented: 0x",
            Witnet.toHexString(uint8(bytes1(msg.sig))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 8))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 16))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 24)))
        )));
    }

    
    // ================================================================================================================
    // --- Yet to be implemented virtual methods ----------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function estimateBaseFee(uint256 _gasPrice, uint256 _resultMaxSize) virtual public view returns (uint256); 

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _maxCallbackGas Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _gasPrice, uint256 _maxCallbackGas) virtual public view returns (uint256);

    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData)
        public
        override
    {
        address _owner = __storage().owner;
        address[] memory _reporters;

        if (_owner == address(0)) {
            // get owner (and reporters) from _initData
            bytes memory _reportersRaw;
            (_owner, _reportersRaw) = abi.decode(_initData, (address, bytes));
            __storage().owner = _owner;
            _reporters = abi.decode(_reportersRaw, (address[]));
        } else {
            // only owner can initialize:
            require(
                msg.sender == _owner,
                "WitnetRequestBoardTrustableBase: not the owner"
            );
            // get reporters from _initData
            _reporters = abi.decode(_initData, (address[]));
        }

        if (__storage().base != address(0)) {
            // current implementation cannot be initialized more than once:
            require(
                __storage().base != base(),
                "WitnetRequestBoardTrustableBase: already upgraded"
            );
        }        
        __storage().base = base();

        require(address(factory).code.length > 0, "WitnetRequestBoardTrustableBase: inexistent factory");
        require(factory.specs() == type(IWitnetRequestFactory).interfaceId, "WitnetRequestBoardTrustableBase: uncompliant factory");
        require(address(factory.witnet()) == address(this), "WitnetRequestBoardTrustableBase: discordant factory");

        // Set reporters
        __setReporters(_reporters);

        emit Upgraded(_owner, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = __storage().owner;
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardAdmin' ----------------------------------------------------------

    /// Gets admin/owner address.
    function owner()
        public view
        override
        returns (address)
    {
        return __storage().owner;
    }

    /// Transfers ownership.
    function transferOwnership(address _newOwner)
        public
        virtual override
        onlyOwner
    {
        address _owner = __storage().owner;
        if (_newOwner != _owner) {
            __storage().owner = _newOwner;
            emit OwnershipTransferred(_owner, _newOwner);
        }
    }


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardAdminACLs' ------------------------------------------------------

    /// Tells whether given address is included in the active reporters control list.
    /// @param _reporter The address to be checked.
    function isReporter(address _reporter) public view override returns (bool) {
        return _acls().isReporter_[_reporter];
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
            _acls().isReporter_[_reporter] = false;
        }
        emit ReportersUnset(_exReporters);
    }


    // ================================================================================================================
    // --- IWitnetRequestBoard Reporter methods -----------------------------------------------------------------------

    /// Reports the Witnet-provided result to a previously posted request. 
    /// @dev Will assume `block.timestamp` as the timestamp at which the request was solved.
    /// @dev Fails if:
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_drTxHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param _queryId The unique identifier of the data request.
    /// @param _drTxHash The hash of the solving tally transaction in Witnet.
    /// @param _cborBytes The result itself as bytes.
    function reportResult(
            uint256 _queryId,
            bytes32 _drTxHash,
            bytes calldata _cborBytes
        )
        external
        override
        onlyReporters
        inStatus(_queryId, Witnet.QueryStatus.Posted)
    {
        require(
            _drTxHash != 0, 
            "WitnetRequestBoardTrustableDefault: Witnet drTxHash cannot be zero"
        );
        // Ensures the result bytes do not have zero length
        // This would not be a valid encoding with CBOR and could trigger a reentrancy attack
        require(
            _cborBytes.length != 0, 
            "WitnetRequestBoardTrustableDefault: result cannot be empty"
        );
        // solhint-disable not-rely-on-time
        _safeTransferTo(
            payable(msg.sender),
            __reportResult(
                _queryId,
                block.timestamp,
                _drTxHash,
                _cborBytes
            )
        );
    }

    /// Reports the Witnet-provided result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_drTxHash` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param _queryId The unique query identifier
    /// @param _timestamp The timestamp of the solving tally transaction in Witnet.
    /// @param _drTxHash The hash of the solving tally transaction in Witnet.
    /// @param _cborBytes The result itself as bytes.
    function reportResult(
            uint256 _queryId,
            uint256 _timestamp,
            bytes32 _drTxHash,
            bytes calldata _cborBytes
        )
        external
        override
        onlyReporters
        inStatus(_queryId, Witnet.QueryStatus.Posted)
    {
        require(
            _timestamp <= block.timestamp, 
            "WitnetRequestBoardTrustableDefault: bad timestamp"
        );
        require(
            _drTxHash != 0, 
            "WitnetRequestBoardTrustableDefault: Witnet drTxHash cannot be zero"
        );
        // Ensures the result bytes do not have zero length (this would not be a valid CBOR encoding 
        // and could trigger a reentrancy attack)
        require(
            _cborBytes.length != 0, 
            "WitnetRequestBoardTrustableDefault: result cannot be empty"
        );
        // Transfer query's reward to the reporter:
        _safeTransferTo(payable(msg.sender), __reportResult(
            _queryId,
            _timestamp,
            _drTxHash,
            _cborBytes
        ));
    }

    /// Reports Witnet-provided results to multiple requests within a single EVM tx.
    /// @dev Fails if called from unauthorized address.
    /// @dev Emits a PostedResult event for every succesfully reported result, if any.
    /// @param _batchResults Array of BatchedResult structs, every one containing:
    ///         - unique query identifier;
    ///         - timestamp of the solving tally txs in Witnet. If zero is provided, EVM-timestamp will be used instead;
    ///         - hash of the corresponding data request tx at the Witnet side-chain level;
    ///         - data request result in raw bytes.
    /// @param _verbose If true, emits a BatchReportError event for every failing report, if any. 
    function reportResultBatch(
            IWitnetRequestBoardReporter.BatchResult[] memory _batchResults,
            bool _verbose
        )
        external
        override
        onlyReporters
    {
        uint _batchReward;
        uint _batchSize = _batchResults.length;
        for ( uint _i = 0; _i < _batchSize; _i ++) {
            BatchResult memory _result = _batchResults[_i];
            if (_statusOf(_result.queryId) != Witnet.QueryStatus.Posted) {
                if (_verbose) {
                    emit BatchReportError(
                        _result.queryId,
                        "WitnetRequestBoardTrustableBase: bad queryId"
                    );
                }
            } else if (_result.drTxHash == 0) {
                if (_verbose) {
                    emit BatchReportError(
                        _result.queryId,
                        "WitnetRequestBoardTrustableBase: bad drTxHash"
                    );
                }
            } else if (_result.cborBytes.length == 0) {
                if (_verbose) {
                    emit BatchReportError(
                        _result.queryId, 
                        "WitnetRequestBoardTrustableBase: bad cborBytes"
                    );
                }
            } else if (_result.timestamp > 0 && _result.timestamp > block.timestamp) {
                if (_verbose) {
                    emit BatchReportError(
                        _result.queryId,
                        "WitnetRequestBoardTrustableBase: bad timestamp"
                    );
                }
            } else {
                _batchReward += __reportResult(
                    _result.queryId,
                    _result.timestamp == 0 ? block.timestamp : _result.timestamp,
                    _result.drTxHash,
                    _result.cborBytes
                );
            }
        }   
        // Transfer all successful rewards in one single shot to the authorized reporter, if any:
        if (_batchReward > 0) {
            _safeTransferTo(
                payable(msg.sender),
                _batchReward
            );
        }
    }
    

    // ================================================================================================================
    // --- IWitnetRequestBoard Requester methods ----------------------------------------------------------------------

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query has been succesfully solved;
    /// @notice   - 3 => Error: the query couldn't get solved due to some issue.
    /// @param _queryId The unique query identifier.
    function checkResultStatus(uint256 _queryId)
        virtual public view
        returns (Witnet.ResultStatus)
    {
        Witnet.QueryStatus _queryStatus = _statusOf(_queryId);
        if (_queryStatus == Witnet.QueryStatus.Reported) {
            bytes storage __cborValues = __seekQueryResponse(_queryId).cborBytes;
            // determine whether reported result is an error by peeking the first byte
            return (__cborValues[0] == bytes1(0xd8) 
                ? Witnet.ResultStatus.Error
                : Witnet.ResultStatus.Ready
            );
        } else if (_queryStatus == Witnet.QueryStatus.Posted) {
            return Witnet.ResultStatus.Awaiting;
        } else {
            return Witnet.ResultStatus.Void;
        }
    }

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param _queryId The unique query identifier.
    function checkResultError(uint256 _queryId)
        override external view
        returns (Witnet.ResultError memory)
    {
        Witnet.ResultStatus _status = checkResultStatus(_queryId);
        try WitnetErrorsLib.asResultError(_status, __seekQueryResponse(_queryId).cborBytes)
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

    /// @notice Returns query's result traceability data
    /// @param _queryId The unique query identifier.
    /// @return _resultTimestamp Timestamp at which the query was solved by the Witnet blockchain.
    /// @return _resultDrTxHash Witnet blockchain hash of the commit/reveal act that solved the query.
    function checkResultTraceability(uint256 _queryId)
        external view
        override
        returns (uint256, bytes32)
    {
        Witnet.Response storage __response = __seekQueryResponse(_queryId);
        return (
            __response.timestamp,
            __response.drTxHash
        );
    }

    /// @notice Estimates the actual earnings (or loss), in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. 
    /// @dev Data requesters should consider upgrading the reward on queries providing no actual earnings.
    function estimateQueryEarnings(uint256 _queryId)
        virtual override
        external view
        returns (int256 _earnings)
    {
        Witnet.Request storage __request = __seekQueryRequest(_queryId);
        _earnings = int(__request.evmReward);
        if (__request.maxCallbackGas > 0) {
            _earnings -= int(estimateBaseFeeWithCallback(
                _getGasPrice(), 
                __request.maxCallbackGas
            ));
        } else {
            _earnings -= int(estimateBaseFee(
                _getGasPrice(),
                registry().lookupRadonRequestResultMaxSize(__request.radHash)
            ));
        }
    }

    /// Retrieves copy of all response data related to a previously posted request, removing the whole query from storage.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _queryId The unique query identifier.
    function fetchQueryResponse(uint256 _queryId)
        public
        virtual override
        onlyRequester(_queryId)
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (Witnet.Response memory _response)
    {
        _response = __seekQuery(_queryId).response;
        delete __storage().queries[_queryId];
    }

    /// Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @param _radHash The radHash of the Witnet Data Request.
    /// @param _slaHash The slaHash of the Witnet Data Request.
    function postRequest(bytes32 _radHash, bytes32 _slaHash)
        virtual override
        public payable
        checkReward(estimateBaseFee(_getGasPrice(), 32))
        returns (uint256 _queryId)
    {
        _queryId = __postRequest(_radHash, _slaHash);
        // Let observers know that a new request has been posted
        emit NewQuery(_queryId, _getMsgValue());
    }

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and 
    /// @notice solved by the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be 
    /// @notice transferred to the reporter who relays back the Witnet-provided result to this request.
    /// @dev Fails if provided reward is too low.
    /// @dev The result to the query will be saved into the WitnetRequestBoard storage.
    /// @param _radHash The RAD hash of the data request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @return _queryId Unique query identifier.
    function postRequest(
            bytes32 _radHash, 
            WitnetV2.RadonSLA calldata _querySLA
        )
        virtual override
        public payable
        checkReward(estimateBaseFee(_getGasPrice(), 32))
        checkSLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __postRequest(
            _radHash, 
            _querySLA.packed()
        );
        // Let observers know that a new request has been posted
        emit NewQuery(_queryId, _getMsgValue());
    }

    /// @notice Requests the execution of the given Witnet Data Request bytecode, in expectation that it will be relayed and 
    /// @notice solved by the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be 
    /// @notice transferred to the reporter who relays back the Witnet-provided result to this request.
    /// @dev Fails if provided reward is too low.
    /// @dev The result to the query will be saved into the WitnetRequestBoard storage.
    /// @param _radBytecode The raw bytecode of the Witnet Data Request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled by the Witnet blockchain.
    /// @return _queryId A unique query identifier.
    function postRequest(
            bytes calldata _radBytecode, 
            WitnetV2.RadonSLA calldata _querySLA
        )
        virtual override
        public payable
        checkReward(estimateBaseFee(_getGasPrice(), 32))
        checkSLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __postRequest(
            registry().hashOf(_radBytecode), 
            _querySLA.packed()
        );
        // Let observers know that a new request has been posted
        emit NewQueryWithBytecode(_queryId, _getMsgValue(), _radBytecode);
    }
   
    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provided result to this request.
    /// @dev Fails if, provided reward is too low.
    /// @dev The caller must be a contract implementing the IWitnetConsumer interface.
    /// @param _radHash The RAD hash of the data request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param _queryMaxCallbackGas Maximum gas to be spent when reporting the data request result.
    /// @return _queryId Unique query identifier.
    function postRequestWithCallback(
            bytes32 _radHash, 
            WitnetV2.RadonSLA calldata _querySLA,
            uint256 _queryMaxCallbackGas
        )
        virtual override
        external payable 
        checkCallbackRecipient(msg.sender)
        checkReward(estimateBaseFeeWithCallback(_getGasPrice(), _queryMaxCallbackGas))
        checkSLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __postRequest(
            _radHash, 
            _querySLA.packed()
        );
        __seekQueryRequest(_queryId).maxCallbackGas = _queryMaxCallbackGas;
        emit NewQuery(_queryId, _getMsgValue());
    }

    /// @notice Requests the execution of the given Witnet Data Request bytecode, in expectation that it will be 
    /// @notice relayed and solved by the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board 
    /// @notice that will be transferred to the reporter who relays back the Witnet-provided result to this request.
    /// @dev Fails if, provided reward is too low.
    /// @dev The caller must be a contract implementing the IWitnetConsumer interface.
    /// @param _radBytecode The RAD hash of the data request to be solved by Witnet.
    /// @param _querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param _queryMaxCallbackGas Maximum gas to be spent when reporting the data request result.
    /// @return _queryId A unique query identifier.
    function postRequestWithCallback(
            bytes calldata _radBytecode,
            WitnetV2.RadonSLA calldata _querySLA,
            uint256 _queryMaxCallbackGas
        )
        virtual override
        external payable
        checkCallbackRecipient(msg.sender)
        checkReward(estimateBaseFeeWithCallback(_getGasPrice(), _queryMaxCallbackGas))
        checkSLA(_querySLA)
        returns (uint256 _queryId)
    {
        _queryId = __postRequest(
            registry().hashOf(_radBytecode),
            _querySLA.packed()
        );
        __seekQueryRequest(_queryId).maxCallbackGas = _queryMaxCallbackGas;
        emit NewQueryWithBytecode(_queryId, _getMsgValue(), _radBytecode);
    }
    
    /// Increments the reward of a previously posted request by adding the transaction value to it.
    /// @dev Updates request `gasPrice` in case this method is called with a higher 
    /// @dev gas price value than the one used in previous calls to `postRequest` or
    /// @dev `upgradeReward`. 
    /// @dev Fails if the `_queryId` is not in 'Posted' status.
    /// @dev Fails also in case the request `gasPrice` is increased, and the new 
    /// @dev reward value gets below new recalculated threshold. 
    /// @param _queryId The unique query identifier.
    function upgradeQueryReward(uint256 _queryId)
        public payable
        virtual override      
        inStatus(_queryId, Witnet.QueryStatus.Posted)
    {
        Witnet.Request storage __request = __seekQueryRequest(_queryId);
        __request.evmReward += _getMsgValue();
        emit QueryRewardUpgraded(_queryId, __request.evmReward);
    }


    // ================================================================================================================
    // --- 'IWitnetRequestBoard' Viewer methods -----------------------------------------------------------------------

    /// Returns next request id to be generated by the Witnet Request Board.
    function getNextQueryId()
        external view 
        override
        returns (uint256)
    {
        return __storage().nonce + 1;
    }

    /// Gets the whole Query data contents, if any, no matter its current status.
    function getQueryData(uint256 _queryId)
      external view
      override
      returns (Witnet.Query memory)
    {
        return __storage().queries[_queryId];
    }

    /// Gets current status of given query.
    function getQueryStatus(uint256 _queryId)
        external view
        override
        returns (Witnet.QueryStatus)
    {
        return _statusOf(_queryId);

    }

    /// Retrieves the whole Request record posted to the Witnet Request Board.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been reported
    /// @dev or deleted.
    /// @param _queryId The unique identifier of a previously posted query.
    function getQueryRequest(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Posted)
        returns (Witnet.Request memory)
    {
        return __seekQueryRequest(_queryId);
    }
    
    /// Retrieves the serialized bytecode of a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not valid, or if the related script bytecode 
    /// @dev got changed after being posted. Returns empty array once it gets reported, 
    /// @dev or deleted.
    /// @param _queryId The unique query identifier.
    function getQueryRequestBytecode(uint256 _queryId)
        external view
        virtual override
        returns (bytes memory _bytecode)
    {
        require(
            _statusOf(_queryId) != Witnet.QueryStatus.Unknown,
            "WitnetRequestBoardTrustableBase: not yet posted"
        );
        Witnet.Request storage __request = __seekQueryRequest(_queryId);
        if (__request._addr != address(0)) {
            _bytecode = IWitnetRequest(__request._addr).bytecode();
        } else if (__request.radHash != bytes32(0)) {
            _bytecode = registry().bytecodeOf(__request.radHash);
        }
    }

    /// Retrieves the Witnet-provided result, and metadata, to a previously posted request.    
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier
    function getQueryResponse(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (Witnet.Response memory _response)
    {
        return __seekQueryResponse(_queryId);
    }

    /// Retrieves the Witnet-provided CBOR-bytes result of a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier
    function getQueryResponseResult(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (Witnet.Result memory)
    {
        Witnet.Response storage _response = __seekQueryResponse(_queryId);
        return _response.cborBytes.resultFromCborBytes();
    }

    /// Retrieves the reward currently set for a previously posted request.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been 
    /// @dev reported, or deleted. 
    /// @param _queryId The unique query identifier
    function getQueryReward(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Posted)
        returns (uint256)
    {
        return __seekQueryRequest(_queryId).evmReward;
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function __newQuery()
        virtual internal returns (uint256)
    {
        return ++ __storage().nonce;
    }

    function __postRequest(bytes32 _radHash, bytes32 _slaPacked)
        virtual internal
        returns (uint256 _queryId)
    {
        _queryId = __newQuery();
        Witnet.Request storage __request = __seekQueryRequest(_queryId);
        {
            __request.radHash = _radHash;
            __request.slaPacked = _slaPacked;
            __request.evmReward = _getMsgValue();
        }
        __seekQuery(_queryId).from = msg.sender;
    }

    function __reportResult(
            uint256 _queryId,
            uint256 _timestamp,
            bytes32 _drTxHash,
            bytes memory _cborBytes
        )
        internal
        returns (uint256 _evmReward)
    {
        Witnet.Query storage __query = __seekQuery(_queryId);
                
        // read and erase query report reward
        Witnet.Request storage __request = __query.request;
        _evmReward = __request.evmReward;
        __request.evmReward = 0; 

        // write report traceability data in storage 
        // (could potentially be deleted from a callback method within same transaction)
        Witnet.Response storage __response = __query.response;
        // solhint-disable not-rely-on-time
        __response.timestamp = _timestamp;
        __response.drTxHash = _drTxHash;
        __response.reporter = msg.sender;

        // determine whether a callback is required
        if (__request.maxCallbackGas > 0) {
            uint _evmCallbackGas = gasleft();
            bool _evmCallbackSuccess; 
            bytes memory _evmCallbackRevertBytes;
            // if callback is required, select which callback method to call 
            // depending on whether the query was solved with or without errors:
            if (_cborBytes[0] == bytes1(0xd8)) {
                WitnetCBOR.CBOR[] memory _errors = WitnetCBOR.fromBytes(_cborBytes).readArray();
                if (_errors.length < 2) {
                    // result with unknown error:
                    (_evmCallbackSuccess, _evmCallbackRevertBytes) = __query.from.call{gas: __request.maxCallbackGas}(
                        abi.encodeWithSelector(IWitnetConsumer.reportWitnetQueryError.selector,
                            _queryId,
                            Witnet.ResultErrorCodes.Unknown,
                            WitnetCBOR.CBOR({
                                buffer: WitnetBuffer.Buffer({ data: hex"", cursor: 0}),
                                initialByte: 0,
                                majorType: 0,
                                additionalInformation: 0,
                                len: 0,
                                tag: 0
                            })
                        )
                    );
                } else {
                    // result with parsable error:
                    (_evmCallbackSuccess, _evmCallbackRevertBytes) = __query.from.call{gas: __request.maxCallbackGas}(
                        abi.encodeWithSelector(IWitnetConsumer.reportWitnetQueryError.selector,
                            _queryId,
                            Witnet.ResultErrorCodes(_errors[0].readUint()),
                            _errors[0]
                        )
                    );
                }
            } else {
                // result with no error
                (_evmCallbackSuccess, _evmCallbackRevertBytes) = __query.from.call{gas: __request.maxCallbackGas}(
                    abi.encodeWithSelector(IWitnetConsumer.reportWitnetQueryResult.selector,
                        _queryId, 
                        WitnetCBOR.fromBytes(_cborBytes)
                    )
                );
            }
            _evmCallbackGas -= gasleft();
            if (_evmCallbackSuccess) {
                emit QueryCallback(
                    _queryId, 
                    _getGasPrice(), 
                    _evmCallbackGas
                );
            } else {
                if (_evmCallbackRevertBytes.length < 68) {
                    emit QueryCallbackRevert(
                        _queryId,
                        _getGasPrice(),
                        _evmCallbackGas,
                        "WitnetRequestBoardTrustableDefault: unhandled callback revert"
                    );    
                } else {
                    assembly {
                        _evmCallbackRevertBytes := add(_evmCallbackRevertBytes, 0x04)
                    }
                    emit QueryCallbackRevert(
                        _queryId,
                        _getGasPrice(),
                        _evmCallbackGas,
                        string(abi.encodePacked(
                            "WitnetRequestBoardTrustableDefault: callback revert: ",
                            _evmCallbackRevertBytes
                        ))
                    );
                }
            }
        } else {
            // no callback is involved, so just keep the cbor-encoded result in storage:
            __response.cborBytes = _cborBytes;
            emit QueryReport(
                _queryId, 
                _getGasPrice()
            );
        }        
    }

    function __setReporters(address[] memory _reporters) internal {
        for (uint ix = 0; ix < _reporters.length; ix ++) {
            address _reporter = _reporters[ix];
            _acls().isReporter_[_reporter] = true;
        }
        emit ReportersSet(_reporters);
    }

}