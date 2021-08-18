// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetRequestBoardUpgradableBase.sol";
import "../../data/WitnetBoardDataACLs.sol";
import "../../interfaces/IWitnetRequestBoardAdmin.sol";
import "../../interfaces/IWitnetRequestBoardAdminACLs.sol";
import "../../patterns/Payable.sol";

/// @title Witnet Request Board "trustable" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitnetRequestBoardTrustableBase
    is 
        Payable,
        IWitnetRequestBoardAdmin,
        IWitnetRequestBoardAdminACLs,        
        WitnetBoardDataACLs,
        WitnetRequestBoardUpgradableBase        
{
    using Witnet for bytes;
    using Witnet for Witnet.Result;

    uint256 internal constant _ESTIMATED_REPORT_RESULT_GAS = 102496;
    
    constructor(bool _upgradable, bytes32 _versionTag, address _currency)
        Payable(_currency)
        WitnetRequestBoardUpgradableBase(_upgradable, _versionTag)
    {}


    // ================================================================================================================
    // --- Overrides 'Upgradable' -------------------------------------------------------------------------------------

    /// Initialize storage-context when invoked as delegatecall. 
    /// Should fail when trying to initialize same instance more than once.
    function initialize(bytes memory _initData) virtual external override {
        address _owner = _state().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            _state().owner = _owner;
        } else {
            // only owner can initialize:
            require(msg.sender == _owner, "WitnetRequestBoardTrustableBase: only owner");
        }        

        if (_state().base != address(0)) {
            // current implementation cannot be initialized more than once:
            require(_state().base != base(), "WitnetRequestBoardTrustableBase: already initialized");
        }        
        _state().base = base();

        emit Initialized(msg.sender, base(), codehash(), version());

        // Do actual base initialization:
        setReporters(abi.decode(_initData, (address[])));
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = _state().owner;
        return (
            // false if the WRB is intrinsically not upgradable
            isUpgradable() && (                
                _owner == address(0) ||
                _owner == _from
            )
        );
    }


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardAdmin' -----------------------------------------------------------------

    /// Gets admin/owner address.
    function owner()
        public view
        override
        returns (address)
    {
        return _state().owner;
    }

    /// Transfers ownership.
    function transferOwnership(address _newOwner)
        external
        virtual override
        onlyOwner
    {
        address _owner = _state().owner;
        if (_newOwner != _owner) {
            _state().owner = _newOwner;
            emit OwnershipTransferred(_owner, _newOwner);
        }
    }


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardAdminACLs' -------------------------------------------------------------

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
    // --- Full implementation of 'IWitnetRequestBoardReporter' --------------------------------------------------------------

    /// Reports the Witnet-provided result to a previously posted request. 
    /// @dev Will asume `block.number` as the Witnet epoch number of the provided result.
    /// @dev Fails if:
    /// @dev   - the `_queryId` is not in 'Posted' status.
    /// @dev   - provided `_witnetProof` is zero;
    /// @dev   - length of provided `_witnetValue` is zero.
    /// @param _queryId The unique identifier of the data request.
    /// @param _witnetProof of the solving tally transaction in Witnet.
    /// @param _witnetResult The result itself as bytes.
    function reportResult(
            uint256 _queryId,
            bytes32 _witnetProof,
            bytes calldata _witnetResult
        )
        external
        override
        onlyReporters
        inStatus(_queryId, Witnet.QueryStatus.Posted)
    {
        _reportResult(_queryId, block.number, _witnetProof, _witnetResult);
    }

    /// Reports the Witnet-provided result to a previously posted request.
    /// @dev Fails if:
    /// @dev   - called from unauthorized address;
    /// @dev   - the `_queryId` is not in 'Posted' status.
    /// @dev   - provided `_witnetProof` is zero;
    /// @dev   - length of provided `_witnetValue` is zero.
    /// @param _queryId The unique identifier of the request.
    /// @param _witnetEpoch of the solving tally transaction in Witnet.
    /// @param _witnetProof of the solving tally transaction in Witnet.
    /// @param _witnetResult The result itself as bytes.
    function reportResult(
            uint256 _queryId,
            uint256 _witnetEpoch,
            bytes32 _witnetProof,
            bytes calldata _witnetResult
        )
        external
        override
        onlyReporters
        inStatus(_queryId, Witnet.QueryStatus.Posted)
    {
        _reportResult(_queryId, _witnetEpoch, _witnetProof, _witnetResult);
    }
    

    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardRequestor' -------------------------------------------------------------

    /// Retrieves Witnet-proved result to a previously posted request, removing the whole query from storage.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _queryId The unique identifier of a previously posted request.
    function destroyResult(uint256 _queryId)
        public
        virtual override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (bytes memory _result)
    {
        require(
            msg.sender == _getRequestData(_queryId).requestor,
            "WitnetRequestBoardTrustableBase: only requestor"
        );
        Witnet.Response storage _response = _getResponseData(_queryId);
        _result = _response.witnetResult;
        delete _state().queries[_queryId];
        emit DestroyedResult(_queryId, msg.sender);
    }

    /// Requests the execution of the given Witnet Radon script in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transfered to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @dev - provided script is zero address.
    /// @dev - provided script bytecode is empty.
    /// @return _queryId The unique identifier of the posted request.
    function postRequest(IWitnetRadon _script)
        public payable
        virtual override
        returns (uint256 _queryId)
    {
        uint256 _value = _getMsgValue();
        uint256 _gasPrice = _getGasPrice();

        // Checks the tally reward is covering gas cost
        uint256 minResultReward = _gasPrice * _ESTIMATED_REPORT_RESULT_GAS;
        require(_value >= minResultReward, "WitnetRequestBoardTrustableBase: reward too low");

        // Validates provided script:
        require(address(_script) != address(0), "WitnetRequestBoardTrustableBase: null script");
        bytes memory _bytecode = _script.bytecode();
        require(_bytecode.length > 0, "WitnetRequestBoardTrustableBase: empty script");

        _queryId = ++ _state().numQueries;

        Witnet.Request storage _request = _getRequestData(_queryId);
        _request.requestor = msg.sender;
        _request.script = _script;
        _request.codehash = _bytecode.computeCodehash();
        _request.gasprice = _gasPrice;
        _request.reward = _value;

        // Let observers know that a new request has been posted
        emit PostedRequest(_queryId, msg.sender);
    }
    
    /// Increments the reward of a data request by adding the transaction value to it.
    /// @dev Updates request `gasPrice` in case this method is called with a higher 
    /// @dev gas price value than the one used in previous calls to `postRequest` or
    /// @dev `upgradeRequest`. 
    /// @dev Fails if the `_queryId` is not in 'Posted' status.
    /// @dev Fails also in case the request `gasPrice` is increased, and the new 
    /// @dev reward value gets below new recalculated threshold. 
    /// @param _queryId The unique identifier of the request.
    function upgradeRequest(uint256 _queryId)
        public payable
        virtual override      
        inStatus(_queryId, Witnet.QueryStatus.Posted)  
    {
        Witnet.Request storage _request = _getRequestData(_queryId);

        uint256 _newReward = _request.reward + _getMsgValue();
        uint256 _newGasPrice = _getGasPrice();

        // If gas price is increased, then check if new rewards cover gas costs
        if (_newGasPrice > _request.gasprice) {
            // Checks the reward is covering gas cost
            uint256 _minResultReward = _newGasPrice * _ESTIMATED_REPORT_RESULT_GAS;
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
        external view
        virtual override
        returns (uint256)
    {
        return _gasPrice * _ESTIMATED_REPORT_RESULT_GAS;
    }

    /// Returns next request id to be generated by the Witnet Request Board.
    function getNextId()
        external view 
        override
        returns (uint256)
    {
        return _state().numQueries + 1;
    }

    /// Gets the whole Query data contents, if any, no matter its current status.
    function getQueryData(uint256 _queryId)
      external view
      override
      returns (Witnet.Query memory)
    {
        return _state().queries[_queryId];
    }

    /// Gets current status of given query.
    function getQueryStatus(uint256 _queryId)
        external view
        override
        returns (Witnet.QueryStatus)
    {
        return _getQueryStatus(_queryId);

    }

    /// Retrieves the whole Request record posted to the Witnet Request Board.
    /// @dev Fails if the `_queryId` is not valid or, if it has been destroyed,
    /// @dev or if the related script bytecode got changed after being posted.
    /// @param _queryId The unique identifier of a previously posted query.
    function readRequest(uint256 _queryId)
        external view
        override
        notDestroyed(_queryId)
        returns (Witnet.Request memory)
    {
        return _checkRequest(_queryId);
    }
    
    /// Retrieves the Radon bytecode of a previously posted request.
    /// @dev Fails if the `_queryId` is not valid or, if it has been destroyed,
    /// @dev or if the related script bytecode got changed after being posted.
    /// @param _queryId The unique identifier of the request query.
    function readRequestBytecode(uint256 _queryId)
        external view
        override
        notDestroyed(_queryId)
        returns (bytes memory _bytecode)
    {
        Witnet.Request storage _request = _getRequestData(_queryId);
        if (address(_request.script) != address(0)) {
            // if DR's request contract address is not zero,
            // we assume the DR has not been destroyed, so
            // DR's bytecode can still be fetched:
            _bytecode = _request.script.bytecode();
            require(
                _bytecode.computeCodehash() == _request.codehash,
                "WitnetRequestBoardTrustableBase: bytecode changed after posting"
            );
        } 
    }

    /// Retrieves the Radon bytecode of a previously posted request.
    /// @dev Fails if the `_queryId` is not valid or, if it has been destroyed,
    /// @dev or if the related script bytecode got changed after being posted.
    /// @param _queryId The unique identifier of the request.
    function readRequestGasPrice(uint256 _queryId)
        external view
        override
        notDestroyed(_queryId)
        returns (uint256)
    {
        return _checkRequest(_queryId).gasprice;
    }

    /// Retrieves the reward currently set for a previously posted request.
    /// @dev Fails if the `_queryId` is not valid or, if it has been destroyed,
    /// @dev or if the related script bytecode got changed after being posted.
    /// @param _queryId The unique identifier of the request.
    function readRequestReward(uint256 _queryId)
        external view
        override
        notDestroyed(_queryId)
        returns (uint256)
    {
        return _checkRequest(_queryId).reward;
    }

    /// Retrieves the Witnet-provided result, and metadata, to a previously posted request.    
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique identifier of the request.
    function readResponse(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (Witnet.Response memory _response)
    {
        return _getResponseData(_queryId);
    }

    /// Retrieves Witnet-provided epoch in which a previously posted request was actually solved by the Witnet DON.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique identifier of the request.
    function readResponseWitnetEpoch(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (uint256)
    {
        return _getResponseData(_queryId).witnetEpoch;
    }

    /// Retrieves the Witnet-provided proof of the reported solution to a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique identifier of the request.
    function readResponseWitnetProof(uint256 _queryId)
        external view        
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (bytes32)
    {
        return _getResponseData(_queryId).witnetProof;
    }

    /// Retrieves the address that reported the result to a previously-posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique identifier of the request.
    function readResponseWitnetReporter(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (address)
    {
        return _getResponseData(_queryId).witnetReporter;
    }

    /// Retrieves the Witnet-provided CBOR-bytes result of a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique identifier of the request.
    function readResponseWitnetResult(uint256 _queryId)
        external view
        override
        inStatus(_queryId, Witnet.QueryStatus.Reported)
        returns (bytes memory)
    {
        Witnet.Response storage _response = _getResponseData(_queryId);
        return _response.witnetResult;
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _checkRequest(uint256 _queryId)
        internal view
        returns (Witnet.Request storage _request)
    {
        _request = _getRequestData(_queryId);
        if (address(_request.script) != address(0)) {
            // if the script contract address is not zero,
            // we assume the query has not been destroyed, so
            // the request script bytecode can still be fetched:
            bytes memory _bytecode = _request.script.bytecode();
            require(
                _bytecode.computeCodehash() == _request.codehash,
                "WitnetRequestBoardTrustableBase: script bytecode changed after posting"
            );
        }        
    }

    function _reportResult(
            uint256 _queryId,
            uint256 _witnetEpoch,
            bytes32 _witnetProof,
            bytes memory _witnetResult
        )
        internal 
    {
        require(_witnetProof != 0, "WitnetRequestBoardTrustableEVM: Witnet proof cannot be zero");
        // Ensures the result byes do not have zero length
        // This would not be a valid encoding with CBOR and could trigger a reentrancy attack
        require(_witnetResult.length != 0, "WitnetRequestBoardTrustableEVM: result cannot be empty");

        Witnet.Query storage _query = _state().queries[_queryId];
        Witnet.Response storage _response = _query.response;

        _response.witnetProof = _witnetProof;
        _response.witnetEpoch = _witnetEpoch;
        _response.witnetReporter = msg.sender;
        _response.witnetResult = _witnetResult;

        _safeTransferTo(payable(msg.sender), _query.request.reward);
        emit PostedResult(_queryId, msg.sender);
    }
}
