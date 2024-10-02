// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../WitnetUpgradableBase.sol";
import "../../../WitnetRequestBoard.sol";
import "../../../data/WitnetBoardDataACLs.sol";
import "../../../interfaces/IWitnetRequestBoardAdminACLs.sol";
import "../../../patterns/Payable.sol";

import "../../../libs/WitnetErrorsLib.sol";

/// @title Witnet Request Board "trustable" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitnetRequestBoardTrustableBase
    is 
        WitnetUpgradableBase,
        WitnetRequestBoard,
        WitnetBoardDataACLs,
        IWitnetRequestBoardAdminACLs,
        Payable 
{
    using Witnet for bytes;
    using Witnet for Witnet.Result;
    
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
        WitnetRequestBoard(_factory)
    {}

    receive() external payable { 
        revert("WitnetRequestBoardTrustableBase: no transfers accepted");
    }

    /// @dev Provide backwards compatibility for dapps bound to versions <= 0.6.1
    /// @dev (i.e. calling methods in IWitnetRequestBoardDeprecating)
    /// @dev (Until 'function ... abi(...)' modifier is allegedly supported in solc versions >= 0.9.1)
    // solhint-disable-next-line payable-fallback
    fallback() override external { /* solhint-disable no-complex-fallback */
        bytes4 _newSig = msg.sig;
        if (msg.sig == 0xA8604C1A) {
            // IWitnetRequestParser.isOk({bool,CBOR}) --> IWitnetRequestBoardDeprecating.isOk({bool,WitnetCBOR.CBOR})
            _newSig = IWitnetRequestBoardDeprecating.isOk.selector;
        } else if (msg.sig == 0xCF62D115) {
            // IWitnetRequestParser.asBytes32({bool,CBOR}) --> IWitnetRequestBoardDeprecating.asBytes32({bool,WitnetCBOR.CBOR})
            _newSig = IWitnetRequestBoardDeprecating.asBytes32.selector;
        } else if (msg.sig == 0xBC7E25FF) {
            // IWitnetRequestParser.asUint64({bool,CBOR}) --> IWitnetRequestBoardDeprecating.asUint64({bool,WitnetCBOR.CBOR})
            _newSig = IWitnetRequestBoardDeprecating.asUint64.selector;
        } else if (msg.sig == 0xD74803BE) {
            // IWitnetRequestParser.asErrorMessage({bool,CBOR}) --> IWitnetRequestBoardDeprecating.asErrorMessage({bool,WitnetCBOR.CBOR})
            _newSig = IWitnetRequestBoardDeprecating.asErrorMessage.selector;
        } else if (msg.sig == 0x109A0E3C) {
            // IWitnetRequestParser.asString({bool,CBOR}) --> IWitnetRequestBoardDeprectating.asString({bool,WitnetCBOR.CBOR})
            _newSig = IWitnetRequestBoardDeprecating.asString.selector;
        }
        if (_newSig != msg.sig) {
            address _self = address(this);
            assembly {
                let ptr := mload(0x40)
                calldatacopy(ptr, 0, calldatasize())
                mstore(ptr, or(and(mload(ptr), 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff), _newSig))
                let result := delegatecall(gas(), _self, ptr, calldatasize(), 0, 0)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                switch result
                    case 0 { revert(ptr, size) }
                    default { return(ptr, size) }
            }
        } else {
            revert(string(abi.encodePacked(
                "WitnetRequestBoardTrustableBase: not implemented: 0x",
                Witnet.toHexString(uint8(bytes1(msg.sig))),
                Witnet.toHexString(uint8(bytes1(msg.sig << 8))),
                Witnet.toHexString(uint8(bytes1(msg.sig << 16))),
                Witnet.toHexString(uint8(bytes1(msg.sig << 24)))
            )));
        }
    }


    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      returns (bool)
    {
        return _interfaceId == type(WitnetRequestBoard).interfaceId
            || _interfaceId == type(IWitnetRequestBoardAdminACLs).interfaceId
            || super.supportsInterface(_interfaceId);
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData)
        public
        override
    {
        address _owner = __storage().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            __storage().owner = _owner;
        } else {
            // only owner can initialize:
            require(
                msg.sender == _owner,
                "WitnetRequestBoardTrustableBase: only owner"
            );
        }

        if (__storage().base != address(0)) {
            // current implementation cannot be initialized more than once:
            require(
                __storage().base != base(),
                "WitnetRequestBoardTrustableBase: already upgraded"
            );
        }        
        __storage().base = base();

        emit Upgraded(msg.sender, base(), codehash(), version());

        // Do actual base initialization:
        setReporters(abi.decode(_initData, (address[])));
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
        for (uint ix = 0; ix < _reporters.length; ix ++) {
            address _reporter = _reporters[ix];
            _acls().isReporter_[_reporter] = true;
        }
        emit ReportersSet(_reporters);
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
    // --- Full implementation of 'IWitnetRequestBoardReporter' -------------------------------------------------------

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
        require(_drTxHash != 0, "WitnetRequestBoardTrustableDefault: Witnet drTxHash cannot be zero");
        // Ensures the result bytes do not have zero length
        // This would not be a valid encoding with CBOR and could trigger a reentrancy attack
        require(_cborBytes.length != 0, "WitnetRequestBoardTrustableDefault: result cannot be empty");
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
        emit PostedResult(_queryId, msg.sender);
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
        require(_timestamp <= block.timestamp, "WitnetRequestBoardTrustableDefault: bad timestamp");
        require(_drTxHash != 0, "WitnetRequestBoardTrustableDefault: Witnet drTxHash cannot be zero");
        // Ensures the result bytes do not have zero length
        // This would not be a valid encoding with CBOR and could trigger a reentrancy attack
        require(_cborBytes.length != 0, "WitnetRequestBoardTrustableDefault: result cannot be empty");
        _safeTransferTo(
            payable(msg.sender),
            __reportResult(
                _queryId,
                _timestamp,
                _drTxHash,
                _cborBytes
            )
        );
        emit PostedResult(_queryId, msg.sender);
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
                emit PostedResult(
                    _result.queryId,
                    msg.sender
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
    // --- Full implementation of 'IWitnetRequestBoardRequestor' ------------------------------------------------------

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
            bytes storage __cborValues = __response(_queryId).cborBytes;
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
        if (_status == Witnet.ResultStatus.Awaiting) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetRequestBoardTrustableBase: not yet solved"
            });
        } else if (_status == Witnet.ResultStatus.Void) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "WitnetRequestBoardTrustableBase: unknown query"
            });
        } else {
            try WitnetErrorsLib.resultErrorFromCborBytes(__response(_queryId).cborBytes)
                returns (Witnet.ResultError memory _error)
            {
                return _error;
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
    }

    /// Retrieves copy of all response data related to a previously posted request, removing the whole query from storage.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _queryId The unique query identifier.
    function deleteQuery(uint256 _queryId)
        public
        virtual override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (Witnet.Response memory _response)
    {
        Witnet.Query storage __query = __storage().queries[_queryId];
        require(
            msg.sender == __query.from,
            "WitnetRequestBoardTrustableBase: only requester"
        );
        _response = __query.response;
        delete __storage().queries[_queryId];
        emit DeletedQuery(_queryId, msg.sender);
    }

    /// Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @dev - provided address is zero.
    /// @param _requestInterface The address of a IWitnetRequest contract, containing the actual Data Request seralized bytecode.
    /// @return _queryId An unique query identifier.
    function postRequest(IWitnetRequest _requestInterface)
        virtual override
        public payable
        returns (uint256 _queryId)
    {
        uint256 _value = _getMsgValue();
        uint256 _gasPrice = _getGasPrice();

        // check base reward
        uint256 _baseReward = estimateReward(_gasPrice);
        require(_value >= _baseReward, "WitnetRequestBoardTrustableBase: reward too low");

        // Validates provided script:
        require(_requestInterface.hash() != bytes32(0), "WitnetRequestBoardTrustableBase: no precompiled request");

        _queryId = ++ __storage().numQueries;
        __storage().queries[_queryId].from = msg.sender;

        Witnet.Request storage _request = __request(_queryId);
        _request.addr = address(_requestInterface);
        _request.gasprice = _gasPrice;
        _request.reward = _value;

        // Let observers know that a new request has been posted
        emit PostedRequest(_queryId, msg.sender);
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
        returns (uint256 _queryId)
    {
        uint256 _value = _getMsgValue();
        uint256 _gasPrice = _getGasPrice();

        // check base reward
        uint256 _baseReward = estimateReward(_gasPrice);
        require(
            _value >= _baseReward,
            "WitnetRequestBoardTrustableBase: reward too low"
        );

        _queryId = ++ __storage().numQueries;
        __storage().queries[_queryId].from = msg.sender;

        Witnet.Request storage _request = __request(_queryId);
        _request.radHash = _radHash;
        _request.slaHash = _slaHash;
        _request.gasprice = _gasPrice;
        _request.reward = _value;

        // Let observers know that a new request has been posted
        emit PostedRequest(_queryId, msg.sender);
    }

    /// Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @param _radHash The RAD hash of the data tequest to be solved by Witnet.
    /// @param _slaParams The SLA param of the data request to be solved by Witnet.
    function postRequest(bytes32 _radHash, Witnet.RadonSLA calldata _slaParams)
        virtual override
        public payable
        returns (uint256 _queryId)
    {
        return postRequest(
            _radHash,
            registry.verifyRadonSLA(_slaParams)
        );
    }
    
    
    /// Increments the reward of a previously posted request by adding the transaction value to it.
    /// @dev Updates request `gasPrice` in case this method is called with a higher 
    /// @dev gas price value than the one used in previous calls to `postRequest` or
    /// @dev `upgradeReward`. 
    /// @dev Fails if the `_queryId` is not in 'Posted' status.
    /// @dev Fails also in case the request `gasPrice` is increased, and the new 
    /// @dev reward value gets below new recalculated threshold. 
    /// @param _queryId The unique query identifier.
    function upgradeReward(uint256 _queryId)
        public payable
        virtual override      
        inStatus(_queryId, Witnet.QueryStatus.Posted)
    {
        Witnet.Request storage _request = __request(_queryId);

        uint256 _newReward = _request.reward + _getMsgValue();
        uint256 _newGasPrice = _getGasPrice();

        // If gas price is increased, then check if new rewards cover gas costs
        if (_newGasPrice > _request.gasprice) {
            // Checks the reward is covering gas cost
            uint256 _minResultReward = estimateReward(_newGasPrice);
            require(
                _newReward >= _minResultReward,
                "WitnetRequestBoardTrustableBase: reward too low"
            );
            _request.gasprice = _newGasPrice;
        }
        _request.reward = _newReward;
    }


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardView' -----------------------------------------------------------

    /// Estimates the amount of reward we need to insert for a given gas price.
    /// @param _gasPrice The gas price for which we need to calculate the rewards.
    function estimateReward(uint256 _gasPrice)
        public view
        virtual override
        returns (uint256);

    /// Returns next request id to be generated by the Witnet Request Board.
    function getNextQueryId()
        external view 
        override
        returns (uint256)
    {
        return __storage().numQueries + 1;
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
    function readRequest(uint256 _queryId)
        public view
        virtual override
        inStatus(_queryId, Witnet.QueryStatus.Posted)
        returns (Witnet.Request memory _request)
    {
        return __request(_queryId);
    }
    
    /// Retrieves the serialized bytecode of a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not valid, or if the related script bytecode 
    /// @dev got changed after being posted. Returns empty array once it gets reported, 
    /// @dev or deleted.
    /// @param _queryId The unique query identifier.
    function readRequestBytecode(uint256 _queryId)
        external view
        virtual override
        returns (bytes memory _bytecode)
    {
        require(
            _statusOf(_queryId) != Witnet.QueryStatus.Unknown,
            "WitnetRequestBoardTrustableBase: not yet posted"
        );
        Witnet.Request storage _request = __request(_queryId);
        if (_request.addr != address(0)) {
            _bytecode = IWitnetRequest(_request.addr).bytecode();
        } else if (_request.radHash != bytes32(0)) {
            _bytecode = registry.bytecodeOf(
                _request.radHash,
                _request.slaHash
            );
        }
    }

    /// Retrieves the gas price that any assigned reporter will have to pay when reporting 
    /// result to a previously posted Witnet data request.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been 
    /// @dev reported, or deleted. 
    /// @param _queryId The unique query identifier
    function readRequestGasPrice(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Posted)
        returns (uint256)
    {
        return __storage().queries[_queryId].request.gasprice;
    }

    /// Retrieves the reward currently set for a previously posted request.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been 
    /// @dev reported, or deleted. 
    /// @param _queryId The unique query identifier
    function readRequestReward(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Posted)
        returns (uint256)
    {
        return __storage().queries[_queryId].request.reward;
    }

    /// Retrieves the Witnet-provided result, and metadata, to a previously posted request.    
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier
    function readResponse(uint256 _queryId)
        public view
        virtual override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (Witnet.Response memory _response)
    {
        return __response(_queryId);
    }

    /// Retrieves the hash of the Witnet transaction that actually solved the referred query.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function readResponseDrTxHash(uint256 _queryId)
        external view        
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (bytes32)
    {
        return __response(_queryId).drTxHash;
    }

    /// Retrieves the address that reported the result to a previously-posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier
    function readResponseReporter(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (address)
    {
        return __response(_queryId).reporter;
    }

    /// Retrieves the Witnet-provided CBOR-bytes result of a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier
    function readResponseResult(uint256 _queryId)
        public view
        virtual override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (Witnet.Result memory)
    {
        Witnet.Response storage _response = __response(_queryId);
        return _response.cborBytes.resultFromCborBytes();
    }

    /// Retrieves the timestamp in which the result to the referred query was solved by the Witnet DON.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function readResponseTimestamp(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (uint256)
    {
        return __response(_queryId).timestamp;
    }


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardDeprecating' interface ------------------------------------------

    /// Tell if a Witnet.Result is successful.
    /// @param _result An instance of Witnet.Result.
    /// @return `true` if successful, `false` if errored.
    function isOk(Witnet.Result memory _result)
        external pure
        override
        returns (bool)
    {
        return _result.success;
    }

    /// Decode a bytes value from a Witnet.Result as a `bytes32` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `bytes32` decoded from the Witnet.Result.
    function asBytes32(Witnet.Result memory _result)
        external pure
        override
        returns (bytes32)
    {
        return _result.asBytes32();
    }

    /// Generate a suitable error message for a member of `Witnet.ResultErrorCodes` and its corresponding arguments.
    /// @dev WARN: Note that client contracts should wrap this function into a try-catch foreseing potential errors generated in this function
    /// @param _result An instance of `Witnet.Result`.
    /// @return A tuple containing the `CBORValue.Error memory` decoded from the `Witnet.Result`, plus a loggable error message.
    function asErrorMessage(Witnet.Result memory _result)
        external pure
        override
        returns (Witnet.ResultErrorCodes, string memory)
    {
        Witnet.ResultError memory _resultError = WitnetErrorsLib.asError(_result);
        return (
            _resultError.code,
            _resultError.reason
        );
    }

    /// Decode a string value from a Witnet.Result as a `string` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The decoded `string` from the Witnet.Result.
    function asString(Witnet.Result memory _result)
        external pure 
        override
        returns (string memory)
    {
        return _result.asText();
    }
    
    /// Decode a natural numeric value from a Witnet.Result as a `uint` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `uint` decoded from the Witnet.Result.
    function asUint64(Witnet.Result memory _result)
        external pure 
        override
        returns (uint64)
    {
        return uint64(_result.asUint());
    }

    /// Decode raw CBOR bytes into a Witnet.Result instance.
    /// @param _cborBytes Raw bytes representing a CBOR-encoded value.
    /// @return A `Witnet.Result` instance.
    function resultFromCborBytes(bytes memory _cborBytes)
        external pure
        override
        returns (Witnet.Result memory)
    {
        return Witnet.resultFromCborBytes(_cborBytes);
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function __reportResult(
            uint256 _queryId,
            uint256 _timestamp,
            bytes32 _drTxHash,
            bytes memory _cborBytes
        )
        internal
        returns (uint256 _reward)
    {
        Witnet.Query storage _query = __query(_queryId);
        Witnet.Request storage _request = _query.request;
        Witnet.Response storage _response = _query.response;

        // solhint-disable not-rely-on-time
        _response.timestamp = _timestamp;
        _response.drTxHash = _drTxHash;
        _response.reporter = msg.sender;
        _response.cborBytes = _cborBytes;

        // return request latest reward
        _reward = _request.reward;

        // Request data won't be needed anymore, so it can just get deleted right now:  
        delete _query.request;
    }
}
