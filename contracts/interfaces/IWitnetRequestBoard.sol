// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/WitnetV2.sol";

interface IWitnetRequestBoard {
    
    /// Emitted when a Witnet Data Request is posted to the WRB.
    event PostedRequest(uint256 queryId, address from);

    /// Emitted when a Witnet-solved result is reported to the WRB.
    event PostedResult(uint256 queryId, address from);

    /// Emitted when all data related to given query is deleted from the WRB.
    event DeletedQuery(uint256 queryId, address from);

    
    /// ===============================================================================================================
    /// --- Requestor interface ---------------------------------------------------------------------------------------
    
    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query has been succesfully solved;
    /// @notice   - 3 => Error: the query couldn't get solved due to some issue.
    /// @param _queryId The unique query identifier.
    function checkResultStatus(uint256 _queryId) external view returns (Witnet.ResultStatus);

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param _queryId The unique query identifier.
    function checkResultError(uint256 _queryId) external view returns (Witnet.ResultError memory);

    /// @notice Retrieves a copy of all Witnet-provided data related to a previously posted request, removing the whole query from the WRB storage.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _queryId The unique query identifier.
    function deleteQuery(uint256 _queryId) external returns (Witnet.Response memory);

    /// @notice Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// @notice A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// @notice result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @dev - provided script is zero address.
    /// @dev - provided script bytecode is empty.
    /// @param addr The address of the IWitnetRequest contract that can provide the actual Data Request bytecode.
    /// @return _queryId Unique query identifier.
    function postRequest(IWitnetRequest addr) external payable returns (uint256 _queryId);

    /// @notice Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// @notice A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// @notice result to this request.
    /// @dev Fails if, provided reward is too low.
    /// @param radHash The RAD hash of the data request to be solved by Witnet.
    /// @param slaHash The SLA hash of the data request to be solved by Witnet.
    /// @return _queryId Unique query identifier.
    function postRequest(bytes32 radHash, bytes32 slaHash) external payable returns (uint256 _queryId);

    /// @notice Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// @notice A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// @notice result to this request.
    /// @dev Fails if, provided reward is too low.
    /// @param radHash The RAD hash of the data request to be solved by Witnet.
    /// @param slaParams The SLA params of the data request to be solved by Witnet.
    /// @return _queryId Unique query identifier.
    function postRequest(bytes32 radHash, WitnetV2.RadonSLA calldata slaParams) external payable returns (uint256 _queryId);

    /// @notice Increments the reward of a previously posted request by adding the transaction value to it.
    /// @dev Updates request `gasPrice` in case this method is called with a higher 
    /// @dev gas price value than the one used in previous calls to `postRequest` or
    /// @dev `upgradeReward`. 
    /// @dev Fails if the `_queryId` is not in 'Posted' status.
    /// @dev Fails also in case the request `gasPrice` is increased, and the new 
    /// @dev reward value gets below new recalculated threshold. 
    /// @param _queryId The unique query identifier.
    function upgradeReward(uint256 _queryId) external payable;
    

    /// ===============================================================================================================
    /// --- Reader interface ------------------------------------------------------------------------------------------

        /// @notice Estimates the amount of reward we need to insert for a given gas price.
    /// @param _gasPrice The gas price for which we need to calculate the rewards.
    function estimateReward(uint256 _gasPrice) external view returns (uint256);

    /// @notice Returns next query id to be generated by the Witnet Request Board.
    function getNextQueryId() external view returns (uint256);

    /// @notice Gets the whole Query data contents, if any, no matter its current status.
    function getQueryData(uint256 _queryId) external view returns (Witnet.Query memory);

    /// @notice Gets current status of given query.
    function getQueryStatus(uint256 _queryId) external view returns (Witnet.QueryStatus);

    /// @notice Retrieves the whole Request record posted to the Witnet Request Board.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been reported
    /// @dev or deleted.
    /// @param _queryId The unique identifier of a previously posted query.
    function readRequest(uint256 _queryId) external view returns (Witnet.Request memory);

    /// @notice Retrieves the serialized bytecode of a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not valid, or if the related script bytecode 
    /// @dev got changed after being posted. Returns empty array once it gets reported, 
    /// @dev or deleted.
    /// @param _queryId The unique query identifier.
    function readRequestBytecode(uint256 _queryId) external view returns (bytes memory);

    /// @notice Retrieves the gas price that any assigned reporter will have to pay when reporting 
    /// result to a previously posted Witnet data request.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been 
    /// @dev reported, or deleted. 
    /// @param _queryId The unique query identifie
    function readRequestGasPrice(uint256 _queryId) external view returns (uint256);

    /// @notice Retrieves the reward currently set for the referred query.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been 
    /// @dev reported, or deleted. 
    /// @param _queryId The unique query identifier.
    function readRequestReward(uint256 _queryId) external view returns (uint256);

    /// @notice Retrieves the whole `Witnet.Response` record referred to a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function readResponse(uint256 _queryId) external view returns (Witnet.Response memory);

    /// @notice Retrieves error codes of given query.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or if no actual error.
    /// @param _queryId The unique query identifier.
    function readResponseDrTxHash(uint256 _queryId) external view returns (bytes32);

    /// @notice Retrieves the address that reported the result to a previously-posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function readResponseReporter(uint256 _queryId) external view returns (address);

    /// @notice Retrieves the Witnet-provided CBOR-bytes result of a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function readResponseResult(uint256 _queryId) external view returns (Witnet.Result memory);

    /// @notice Retrieves the timestamp in which the result to the referred query was solved by the Witnet DON.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function readResponseTimestamp(uint256 _queryId) external view returns (uint256);


    /// ===============================================================================================================
    /// --- Deprecating funcionality v0.5 -----------------------------------------------------------------------------
    
    /// Tell if a Witnet.Result is successful.
    /// @param _result An instance of Witnet.Result.
    /// @return `true` if successful, `false` if errored.
    function isOk(Witnet.Result memory _result) external pure returns (bool);

    /// Decode a bytes value from a Witnet.Result as a `bytes32` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `bytes32` decoded from the Witnet.Result.
    function asBytes32(Witnet.Result memory _result) external pure returns (bytes32);

    /// Generate a suitable error message for a member of `Witnet.ResultErrorCodes` and its corresponding arguments.
    /// @dev WARN: Note that client contracts should wrap this function into a try-catch foreseing potential errors generated in this function
    /// @param _result An instance of `Witnet.Result`.
    /// @return A tuple containing the `CBORValue.Error memory` decoded from the `Witnet.Result`, plus a loggable error message.
    function asErrorMessage(Witnet.Result memory _result) external pure returns (Witnet.ResultErrorCodes, string memory);

    /// Decode a natural numeric value from a Witnet.Result as a `uint` value.
    /// @param _result An instance of Witnet.Result.
    /// @return The `uint` decoded from the Witnet.Result.
    function asUint64(Witnet.Result memory _result) external pure returns (uint64);

    /// Decode raw CBOR bytes into a Witnet.Result instance.
    /// @param _cborBytes Raw bytes representing a CBOR-encoded value.
    /// @return A `Witnet.Result` instance.
    function resultFromCborBytes(bytes memory _cborBytes) external pure returns (Witnet.Result memory);

}