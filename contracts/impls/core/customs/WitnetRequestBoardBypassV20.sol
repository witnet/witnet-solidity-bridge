// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../../WitnetUpgradableBase.sol";
import "../../../WitnetRequestBoard.sol";
import "../../../data/WitnetBoardDataACLs.sol";

import "../../../interfaces/V2/IWitnetConsumer.sol";
import "../../../interfaces/V2/IWitnetOracle.sol";
import "../../../interfaces/V2/IWitnetOracleEvents.sol";

abstract contract WitnetOracleV07 {
    
    WitnetRequestFactory immutable public factory;
    WitnetBytecodes immutable public registry;

    constructor (WitnetRequestFactory _factory) {
        require(
            _factory.class() == type(WitnetRequestFactory).interfaceId,
            "WitnetRequestBoardBypassV20: uncompliant factory"
        );
        factory = _factory;
        registry = _factory.registry();
    }
}

abstract contract WitnetOracleV20
    is
        IWitnetOracle,
        IWitnetOracleEvents
{
    function specs() virtual external view returns (bytes4);
}

/// @title Witnet Request Board bypass implementation to V2.0 
/// @author The Witnet Foundation
contract WitnetRequestBoardBypassV20
    is 
        IWitnetConsumer,
        IWitnetOracleEvents,
        IWitnetRequestBoardEvents,
        WitnetUpgradableBase,
        WitnetOracleV07,
        WitnetBoardDataACLs
{
    using ERC165Checker for address;

    using Witnet for bytes;
    using Witnet for Witnet.Result;

    WitnetOracleV07 immutable public legacy;
    WitnetOracleV20 immutable public surrogate;

    uint8  constant internal _DEFAULT_SLA_COMMITTEE_SIZE = 10;
    uint64 constant internal _DEFAULT_SLA_WITNESSING_FEE_NANOWIT = 200000000;
    
    function defaultRadonSLA() virtual public pure returns (WitnetV2.RadonSLA memory) {
        return WitnetV2.RadonSLA({
            committeeSize: _DEFAULT_SLA_COMMITTEE_SIZE,
            witnessingFeeNanoWit: _DEFAULT_SLA_WITNESSING_FEE_NANOWIT
        });
    }

    modifier legacyFallback(uint256 queryId) {
        if (queryId < __storage().numQueries) {
            __legacyFallback();
        } else {
            _;
        }
    }

    modifier onlySurrogate {
        require(
            msg.sender == address(surrogate),
            "WitnetRequestBoardBypassV20: only surrogate"
        ); _;
    }
    
    constructor(
            WitnetOracleV07 _legacy,
            WitnetOracleV20 _surrogate,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetOracleV07(_legacy.factory())
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.board"
        )
    {
        legacy = _legacy;
        require(
            address(_surrogate).code.length > 0
                && _surrogate.specs() == type(IWitnetOracle).interfaceId,
            "WitnetRequestBoardBypassV20: uncompliant WitnetOracle"
        );
        surrogate = _surrogate;
    }

    receive() external payable { 
        revert("WitnetRequestBoardBypassV20: no transfers accepted");
    }

    /// @dev Fallback unhandled methods to whatever the late legacy implementation supported
    // solhint-disable-next-line payable-fallback
    fallback() virtual override external { /* solhint-disable no-complex-fallback */
        __legacyFallback();
    }


    // ================================================================================================================
    // --- Implementation of IERC165 interface ------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return (
            _interfaceId == type(WitnetRequestBoard).interfaceId
                || super.supportsInterface(_interfaceId)
        );
    }


    // ================================================================================================================
    // --- Implementation of 'Upgradeable' ----------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory) public override {
        address _owner = __storage().owner;
        if (_owner == address(0)) {
            revert("WitnetRequestBoardBypassV20: cannot bypass uninitialized proxy");
        } else {
            // only owner can initialize:
            require(
                msg.sender == _owner,
                "WitnetRequestBoardBypassV20: only legacy owner"
            );
        }

        if (__storage().base != address(0)) {
            // current implementation cannot be initialized more than once:
            require(
                __storage().base != base(),
                "WitnetRequestBoardBypassV20: already upgraded"
            );
        }        
        __storage().base = base();

        emit Upgraded(msg.sender, base(), codehash(), version());
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
    // --- Implementation of 'Ownable' --------------------------------------------------------------------------------

    /// Gets admin/owner address.
    function owner() public view override returns (address) {
        return __storage().owner;
    }

    /// Transfers ownership.
    function transferOwnership(address _newOwner) public override onlyOwner {
        address _owner = __storage().owner;
        if (_newOwner != _owner) {
            __storage().owner = _newOwner;
            emit OwnershipTransferred(_owner, _newOwner);
        }
    }


    // ================================================================================================================
    // --- Implementation of 'IWitnetConsumer' ------------------------------------------------------------------------

    /// @notice Method to be called from the WitnetOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported with no errors.
    /// @dev It should revert if called from any other address different to the WitnetOracle being used
    /// @dev by the WitnetConsumer contract. 
    /// @param _witnetQueryId The unique identifier of the Witnet query being reported.
    /// @param _witnetResultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _witnetResultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param _witnetResultCborValue The CBOR-encoded resulting value of the Witnet query being reported.
    function reportWitnetQueryResult(
            uint256 _witnetQueryId, 
            uint64  _witnetResultTimestamp,
            bytes32 _witnetResultTallyHash,
            uint256,
            WitnetCBOR.CBOR calldata _witnetResultCborValue
        ) 
        external override
        onlySurrogate 
    {
        _witnetQueryId += __storage().numQueries;
        require(
            _statusOf(_witnetQueryId) == Witnet.QueryStatus.Posted,
            "WitnetRequestBoardBypassV20: not in Posted status"
        );
        Witnet.Query storage __record = __storage().queries[_witnetQueryId];
        __record.response = Witnet.Response({
            reporter: msg.sender,
            timestamp: uint256(_witnetResultTimestamp),
            drTxHash: _witnetResultTallyHash,
            cborBytes: _witnetResultCborValue.buffer.data
        });
        emit PostedResult(_witnetQueryId, msg.sender);
    }

    /// @notice Method to be called from the WitnetOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported WITH errors.
    /// @dev It should revert if called from any other address different to the WitnetOracle being used
    /// @dev by the WitnetConsumer contract. 
    /// @param _witnetQueryId The unique identifier of the Witnet query being reported.
    /// @param _witnetResultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param _witnetResultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param _errorArgs Error arguments, if any. An empty buffer is to be passed if no error arguments apply.
    function reportWitnetQueryError(
            uint256 _witnetQueryId, 
            uint64  _witnetResultTimestamp,
            bytes32 _witnetResultTallyHash,
            uint256,
            Witnet.ResultErrorCodes, 
            WitnetCBOR.CBOR calldata _errorArgs
        ) 
        external override
        onlySurrogate
    {
        _witnetQueryId += __storage().numQueries;    
        require(
            _statusOf(_witnetQueryId) == Witnet.QueryStatus.Posted,
            "WitnetRequestBoardBypassV20: not in Posted status"
        );
        Witnet.Query storage __record = __storage().queries[_witnetQueryId];
        __record.response = Witnet.Response({
            reporter: msg.sender,
            timestamp: uint256(_witnetResultTimestamp),
            drTxHash: _witnetResultTallyHash,
            cborBytes: _errorArgs.buffer.data
        });
        emit PostedResult(_witnetQueryId, msg.sender);
    }


    /// @notice Determines if Witnet queries can be reported from given address.
    /// @dev In practice, must only be true on the WitnetOracle address that's being used by
    /// @dev the WitnetConsumer to post queries. 
    function reportableFrom(address _from) external view override returns (bool) {
        return (
            _from == address(surrogate)
        );
    }


    // ================================================================================================================
    // --- Interception of 'IWitnetRequestBoardReporter' --------------------------------------------------------------

    function reportResult(uint256 _queryId, bytes32, bytes calldata) external legacyFallback(_queryId) {
        revert("WitnetRequestBoardBypassV20: not permitted");
    }
    function reportResult(uint256 _queryId, uint256, bytes32, bytes calldata) external legacyFallback(_queryId) {
        revert("WitnetRequestBoardBypassV20: not permitted");
    }
    function reportResultBatch(IWitnetRequestBoardReporter.BatchResult[] memory, bool) external pure {
        revert("WitnetRequestBoardBypassV20: not permitted");
    }


    // ================================================================================================================
    // --- Partial interception of 'IWitnetRequestBoardRequestor' -----------------------------------------------------

    /// Retrieves copy of all response data related to a previously posted request, removing the whole query from storage.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _queryId The unique query identifier.
    function deleteQuery(uint256 _queryId) public legacyFallback(_queryId) returns (Witnet.Response memory _response) {
        Witnet.Query storage __record = __storage().queries[_queryId];
        require(
            msg.sender == __record.from,
            "WitnetRequestBoardBypassV20: only requester"
        );
        _response = __record.response;
        delete __storage().queries[_queryId];
        surrogate.fetchQueryResponse(
            _queryId - __storage().numQueries
        );
    }

    /// Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @dev - provided address is zero.
    /// @param _witnetRequest The address of a IWitnetRequest contract, containing the actual Data Request seralized bytecode.
    /// @return _queryId An unique query identifier.
    function postRequest(IWitnetRequest _witnetRequest) public payable returns (uint256 _queryId) {
        _queryId = (
            __storage().numQueries +
                surrogate.postRequestWithCallback{
                    value: msg.value
                }(
                    _witnetRequest.bytecode(),
                    defaultRadonSLA(),
                    _legacyEstimateCallbackLimit(tx.gasprice)
                )
        );
        __storage().queries[_queryId].from = msg.sender;
        __storage().queries[_queryId].request.addr = address(_witnetRequest);
        __storage().queries[_queryId].request.gasprice = tx.gasprice;
    }

    /// Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @param _radHash The radHash of the Witnet Data Request.
    /// @param _slaHash The slaHash of the Witnet Data Request.
    function postRequest(bytes32 _radHash, bytes32 _slaHash) public payable returns (uint256 _queryId) {
        Witnet.RadonSLA memory _slaParams = registry.lookupRadonSLA(_slaHash);
        _queryId = (
            __storage().numQueries +
                surrogate.postRequestWithCallback{
                    value: msg.value
                }(
                    registry.bytecodeOf(_radHash),
                    WitnetV2.RadonSLA({
                        committeeSize: _slaParams.numWitnesses,
                        witnessingFeeNanoWit: _slaParams.witnessCollateral / 100
                    }),
                    _legacyEstimateCallbackLimit(tx.gasprice)
                )
        );
        __storage().queries[_queryId].from = msg.sender;
        __storage().queries[_queryId].request.gasprice = tx.gasprice;
        __storage().queries[_queryId].request.radHash = _radHash;
        __storage().queries[_queryId].request.slaHash = _slaHash;
    }

    /// Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @param _radHash The RAD hash of the data tequest to be solved by Witnet.
    /// @param _slaParams The SLA param of the data request to be solved by Witnet.
    function postRequest(bytes32 _radHash, Witnet.RadonSLA calldata _slaParams) public payable returns (uint256 _queryId) {
        _queryId = (
            __storage().numQueries +
                surrogate.postRequestWithCallback{
                    value: msg.value
                }(
                    registry.bytecodeOf(_radHash),
                    WitnetV2.RadonSLA({
                        committeeSize: _slaParams.numWitnesses,
                        witnessingFeeNanoWit: _slaParams.witnessCollateral / 100
                    }),
                    _legacyEstimateCallbackLimit(tx.gasprice)
                )
        );
        __storage().queries[_queryId].from = msg.sender;
        __storage().queries[_queryId].request.gasprice = tx.gasprice;
        __storage().queries[_queryId].request.radHash = _radHash;
        __storage().queries[_queryId].request.slaHash = registry.verifyRadonSLA(_slaParams);
    }
    
    /// Increments the reward of a previously posted request by adding the transaction value to it.
    /// @dev Updates request `gasPrice` in case this method is called with a higher 
    /// @dev gas price value than the one used in previous calls to `postRequest` or
    /// @dev `upgradeReward`. 
    /// @dev Fails if the `_queryId` is not in 'Posted' status.
    /// @dev Fails also in case the request `gasPrice` is increased, and the new 
    /// @dev reward value gets below new recalculated threshold. 
    /// @param _queryId The unique query identifier.
    function upgradeReward(uint256 _queryId) public payable legacyFallback(_queryId) {
        surrogate.upgradeQueryEvmReward{
            value: msg.value
        }(
            _queryId - __storage().numQueries
        );
        if (__request(_queryId).gasprice < tx.gasprice) {
            __request(_queryId).gasprice = tx.gasprice;
        }
    }


    // ================================================================================================================
    // --- Partial interception of 'IWitnetRequestBoardView' ----------------------------------------------------------

    /// Estimates the amount of reward we need to insert for a given gas price.
    /// @param _gasPrice The gas price for which we need to calculate the rewards.
    function estimateReward(uint256 _gasPrice) public returns (uint256) {
        return surrogate.estimateBaseFeeWithCallback(
            _gasPrice, 
            _legacyEstimateCallbackLimit(_gasPrice)
        );
    }

    /// Returns next request id to be generated by the Witnet Request Board.
    function getNextQueryId() external view returns (uint256) {
        return (
            __storage().numQueries 
                + surrogate.getNextQueryId()
        );
    }

    /// Gets the whole Query data contents, if any, no matter its current status.
    function getQueryData(uint256 _queryId) external legacyFallback(_queryId) returns (Witnet.Query memory) {
        return Witnet.Query({
            from: __query(_queryId).from,
            request: Witnet.Request({
                addr: __request(_queryId).addr,
                gasprice: __request(_queryId).gasprice,
                slaHash: __request(_queryId).slaHash,
                radHash: __request(_queryId).radHash,
                reward: surrogate.getQueryEvmReward(_queryId - __storage().numQueries)
            }),
            response: __storage().queries[_queryId].response
        });
    }

    /// Retrieves the whole Request record posted to the Witnet Request Board.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been reported
    /// @dev or deleted.
    /// @param _queryId The unique identifier of a previously posted query.
    function readRequest(uint256 _queryId) public legacyFallback(_queryId) returns (Witnet.Request memory _request) {
        return Witnet.Request({
            addr: __request(_queryId).addr,
            slaHash: __request(_queryId).slaHash,
            radHash: __request(_queryId).radHash,
            gasprice: __request(_queryId).gasprice,
            reward: surrogate.getQueryEvmReward(
                _queryId - __storage().numQueries
            )
        });
    }
    
    /// Retrieves the serialized bytecode of a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not valid, or if the related script bytecode 
    /// @dev got changed after being posted. Returns empty array once it gets reported, 
    /// @dev or deleted.
    /// @param _queryId The unique query identifier.
    function readRequestBytecode(uint256 _queryId) external legacyFallback(_queryId) returns (bytes memory _bytecode) {
        WitnetV2.Request memory _requestV2 = surrogate.getQueryRequest(
            _queryId - __storage().numQueries
        );
        return _requestV2.witnetBytecode;
    }

    /// Retrieves the reward currently set for a previously posted request.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been 
    /// @dev reported, or deleted. 
    /// @param _queryId The unique query identifier
    function readRequestReward(uint256 _queryId) external legacyFallback(_queryId) returns (uint256) {
        return surrogate.getQueryEvmReward(
            _queryId - __storage().numQueries
        );
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _legacyEstimateCallbackLimit(uint256 _gasPrice) internal returns (uint24) {
        (
            bool _success, 
            bytes memory _data
        ) = address(legacy).delegatecall(
            abi.encodeWithSignature("estimateReward(uint256)", _gasPrice)
        );
        require(
            _success, 
            "WitnetRequestBoardBypassV20: cannot delegate reward estimation"
        );
        return uint24(
            abi.decode(_data, (uint256)) 
                / _gasPrice
        );
    }

    function __legacyFallback() internal {
        address _legacy = address(legacy);
        assembly { /* solhint-disable avoid-low-level-calls */
            // Gas optimized delegate call to 'implementation' contract.
            // Note: `msg.data`, `msg.sender` and `msg.value` will be passed over 
            //       to actual implementation of `msg.sig` within `implementation` contract.
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _legacy, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
                case 0  { 
                    // pass back revert message:
                    revert(ptr, size) 
                }
                default {
                  // pass back same data as returned by 'implementation' contract:
                  return(ptr, size) 
                }
        }
    }
}
