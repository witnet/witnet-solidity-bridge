// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetUpgradableBase.sol";
import "../../WitOracle.sol";
import "../../data/WitOracleDataLib.sol";
import "../../interfaces/IWitOracleLegacy.sol";
import "../../interfaces/IWitOracleReporter.sol";
import "../../interfaces/IWitOracleAdminACLs.sol";
import "../../interfaces/IWitOracleConsumer.sol";
import "../../libs/WitOracleResultErrorsLib.sol";
import "../../patterns/Payable.sol";

/// @title Witnet Request Board "trustable" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleTrustableBase
    is 
        Payable,
        WitOracle,
        WitnetUpgradableBase,
        IWitOracleLegacy,
        IWitOracleReporter,
        IWitOracleAdminACLs
{
    using Witnet for bytes;
    using Witnet for Witnet.QueryRequest;
    using Witnet for Witnet.QueryResponse;
    using Witnet for Witnet.RadonSLA;
    using Witnet for Witnet.Result;

    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitOracleDataLib for WitOracleDataLib.Storage;

    WitOracleRequestFactory public immutable override factory;
    WitOracleRadonRegistry public immutable override registry;
    
    bytes4 public immutable override specs = type(WitOracle).interfaceId;

    function channel() virtual override public view returns (bytes4) {
        return bytes4(keccak256(abi.encode(address(this), block.chainid)));
    }

    function class()
        public view
        virtual override(IWitAppliance, WitnetUpgradableBase) 
        returns (string memory)
    {
        return type(WitOracleTrustableBase).name;
    }

    modifier checkCallbackRecipient(
            IWitOracleConsumer _consumer, 
            uint24 _callbackGasLimit
    ) virtual {
        _require(
            address(_consumer).code.length > 0
                && _consumer.reportableFrom(address(this))
                && _callbackGasLimit > 0,
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

    /// Asserts the caller is authorized as a reporter
    modifier onlyReporters {
        _require(
            __storage().reporters[msg.sender],
            "unauthorized reporter"
        ); _;
    }
    
    constructor(
            WitOracleRadonRegistry _registry,
            WitOracleRequestFactory _factory,
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
        registry = _registry;
        factory = _factory;
    }

    /// @dev Provide backwards compatibility for dapps bound to versions <= 0.6.1
    /// @dev (i.e. calling methods in IWitOracle)
    /// @dev (Until 'function ... abi(...)' modifier is allegedly supported in solc versions >= 0.9.1)
    /* solhint-disable payable-fallback */
    /* solhint-disable no-complex-fallback */
    fallback() override external { 
        _revert(string(abi.encodePacked(
            "not implemented: 0x",
            Witnet.toHexString(uint8(bytes1(msg.sig))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 8))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 16))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 24)))
        )));
    }

    
    // ================================================================================================================
    // --- Yet to be implemented virtual methods ----------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @param evmGasPrice Expected gas price to pay upon posting the data request.
    function estimateBaseFee(uint256 evmGasPrice) virtual public view returns (uint256);

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param evmGasPrice Expected gas price to pay upon posting the data request.
    /// @param evmCallbackGas Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 evmGasPrice, uint24 evmCallbackGas)
        virtual public view returns (uint256);

    /// @notice Estimate the extra reward (i.e. over the base fee) to be paid when posting a new
    /// @notice data query in order to avoid getting provable "too low incentives" results from
    /// @notice the Wit/oracle blockchain. 
    /// @dev The extra fee gets calculated in proportion to:
    /// @param evmGasPrice Tentative EVM gas price at the moment the query result is ready.
    /// @param evmWitPrice Tentative nanoWit price in Wei at the moment the query is solved on the Wit/oracle blockchain.
    /// @param querySLA The query SLA data security parameters as required for the Wit/oracle blockchain. 
    function estimateExtraFee(uint256 evmGasPrice, uint256 evmWitPrice, Witnet.RadonSLA memory querySLA)
        virtual public view returns (uint256);

    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData) virtual override public {
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
            _require(
                msg.sender == _owner,
                "not the owner"
            );
            // get reporters from _initData
            _newReporters = abi.decode(_initData, (address[]));
        }

        if (
            __proxiable().codehash != bytes32(0)
                && __proxiable().codehash == codehash()
        ) {
            _revert("already upgraded");
        }
        __proxiable().codehash = codehash();

        _require(address(registry).code.length > 0, "inexistent registry");
        _require(registry.specs() == type(WitOracleRadonRegistry).interfaceId, "uncompliant registry");
        
        // Set reporters, if any
        WitOracleDataLib.setReporters(_newReporters);

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
    // --- Partial implementation of IWitOracle --------------------------------------------------------------

    /// Retrieves copy of all response data related to a previously posted request, removing the whole query from storage.
    /// @dev Fails if the `_queryId` is not in 'Finalized' or 'Expired' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @dev If in 'Expired' status, query reward is transfer back to the requester.
    /// @param _queryId The unique query identifier.
    function fetchQueryResponse(uint256 _queryId)
        virtual override
        external
        onlyRequester(_queryId)
        returns (Witnet.QueryResponse memory _response)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatus(_queryId);

        uint72 _evmReward;
        if (_queryStatus == Witnet.QueryStatus.Expired) {
            _evmReward = WitOracleDataLib.seekQueryRequest(_queryId).evmReward;

        } else if (_queryStatus != Witnet.QueryStatus.Finalized) {
            _revertInvalidQueryStatus(_queryStatus);
        }

        // delete query metadata from storage:
        _response = WitOracleDataLib.seekQuery(_queryId).response;
        delete __storage().queries[_queryId];

        if (_evmReward > 0) {
            // transfer unused reward to requester, only if the query expired:
            __safeTransferTo(
                payable(msg.sender),
                _evmReward
            );
        }
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

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query has been succesfully solved;
    /// @notice   - 3 => Error: the query couldn't get solved due to some issue.
    /// @param _queryId The unique query identifier.
    function getQueryResponseStatus(uint256 _queryId)
        virtual override
        public view
        returns (Witnet.QueryResponseStatus)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatus(_queryId);
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            bytes storage __cborValues = WitOracleDataLib.seekQueryResponse(_queryId).resultCborBytes;
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
        
        } else if (_queryStatus == Witnet.QueryStatus.Posted) {
            return Witnet.QueryResponseStatus.Awaiting;
        
        } else if (_queryStatus == Witnet.QueryStatus.Expired) {
            return Witnet.QueryResponseStatus.Expired;
        
        } else {
            return Witnet.QueryResponseStatus.Void;
        }
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

    /// Gets current status of given query.
    function getQueryStatus(uint256 _queryId)
        virtual override
        public view
        returns (Witnet.QueryStatus)
    {
        Witnet.Query storage __query = WitOracleDataLib.seekQuery(_queryId);
        if (__query.response.resultTimestamp != 0) {
            return Witnet.QueryStatus.Finalized;
            
        } else if (__query.block == 0) {
            return Witnet.QueryStatus.Unknown;
        
        } else if (block.number >= __query.block + 64) {
            return Witnet.QueryStatus.Expired;
        
        } else {
            return Witnet.QueryStatus.Posted;

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
            _msgSender(), 
            _queryRAD, 
            _querySLA, 
            0
        );
        // Let Web3 observers know that a new request has been posted
        emit WitOracleQuery(
            _msgSender(),
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
            IWitOracleConsumer(_msgSender()),
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
            _queryRAD,
            _querySLA,
            _queryCallbackGasLimit
        );
        emit WitOracleQuery(
            _msgSender(),
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
            IWitOracleConsumer(_msgSender()),
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
            bytes32(0),
            _querySLA,
            _queryCallbackGasLimit
        );
        WitOracleDataLib.seekQueryRequest(_queryId).radonBytecode = _queryUnverifiedBytecode;
        emit WitOracleQuery(
            _msgSender(),
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
            _msgSender(),
            _getGasPrice(),
            __request.evmReward
        );
    }


    /// ===============================================================================================================
    /// --- IWitOracleLegacy ---------------------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param evmGasPrice Expected gas price to pay upon posting the data request.
    /// @param maxResultSize Maximum expected size of returned data (in bytes).
    function estimateBaseFee(uint256 evmGasPrice, uint16 maxResultSize)
        virtual public view returns (uint256); 

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
    // --- Full implementation of IWitOracleReporter ------------------------------------------------------------------

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
            if (
                getQueryStatus(_queryIds[_ix]) == Witnet.QueryStatus.Posted
            ) {
                Witnet.QueryRequest storage __request = WitOracleDataLib.seekQueryRequest(_queryIds[_ix]);
                if (__request.gasCallback > 0) {
                    _expenses += (
                        estimateBaseFeeWithCallback(_evmGasPrice, __request.gasCallback)
                            + estimateExtraFee(
                                _evmGasPrice,
                                _evmWitPrice,
                                Witnet.RadonSLA({
                                    witNumWitnesses: __request.radonSLA.witNumWitnesses,
                                    witUnitaryReward: __request.radonSLA.witUnitaryReward,
                                    maxTallyResultSize: uint16(0)
                                })
                            )
                    );
                } else {
                    _expenses += (
                        estimateBaseFee(_evmGasPrice)
                            + estimateExtraFee(
                                _evmGasPrice, 
                                _evmWitPrice, 
                                __request.radonSLA
                            )
                    );
                }
                _expenses +=  _evmWitPrice * __request.radonSLA.witUnitaryReward;
                _revenues += __request.evmReward;
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
        inStatus(_queryId, Witnet.QueryStatus.Posted)
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
        inStatus(_queryId, Witnet.QueryStatus.Posted)
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
    function reportResultBatch(IWitOracleReporter.BatchResult[] calldata _batchResults)
        external override
        onlyReporters
        returns (uint256 _batchReward)
    {
        for (uint _i = 0; _i < _batchResults.length; _i ++) {
            if (
                WitOracleDataLib.seekQueryStatus(_batchResults[_i].queryId)
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


    // ================================================================================================================
    // --- Full implementation of 'IWitOracleAdminACLs' ---------------------------------------------------------------

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


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _revertInvalidQueryStatus(Witnet.QueryStatus _queryStatus) virtual internal {
        _revert(
            string(abi.encodePacked(
                "invalid query status: ",
                WitOracleDataLib.toString(_queryStatus)
            ))
        );
    }

    function __postQuery(
            address _requester,
            bytes32 _radHash, 
            Witnet.RadonSLA memory _sla, 
            uint24 _callbackGasLimit
        )
        virtual internal
        returns (uint256 _queryId)
    {
        _queryId = ++ __storage().nonce; //__newQueryId(_radHash, _packedSLA);
        Witnet.QueryRequest storage __request = WitOracleDataLib.seekQueryRequest(_queryId);
        _require(__request.requester == address(0), "already posted");
        {
            __request.requester = _requester;
            __request.gasCallback = _callbackGasLimit;
            __request.evmReward = uint72(_getMsgValue());
            __request.radonRadHash = _radHash;
            __request.radonSLA = _sla;
        }
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
        return WitOracleDataLib.reportResult(
            _getGasPrice(),
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
    function __storage() virtual internal pure returns (WitOracleDataLib.Storage storage _ptr) {
      return WitOracleDataLib.data();
    }
}
