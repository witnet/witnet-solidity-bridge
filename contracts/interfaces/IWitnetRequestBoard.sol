// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/WitnetV2.sol";

interface IWitnetRequestBoard {
    
    /// Emitted when a Witnet Data Request is posted to the WRB.
    event PostedRequest(uint256 indexed queryId, address from);

    /// Emitted when a Witnet-solved result is reported to the WRB.
    event PostedResult(uint256 indexed queryId, address from);

    /// Emitted when the reward of some not-yet reported query is upgraded.
    event UpgradedReward(uint256 indexed queryId);

    
    /// ===============================================================================================================
    /// --- Requester interface ---------------------------------------------------------------------------------------
    
    /// @notice Delete query without further ado.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _queryId The unique query identifier.
    function burnQuery(uint256 _queryId) external;

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param _queryId The unique query identifier.
    function checkResultError(uint256 _queryId) external view returns (Witnet.ResultError memory);

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query has been succesfully solved;
    /// @notice   - 3 => Error: the query couldn't get solved due to some issue.
    /// @param _queryId The unique query identifier.
    function checkResultStatus(uint256 _queryId) external view returns (Witnet.ResultStatus);

    /// @notice Returns query's result traceability data
    /// @param _queryId The unique query identifier.
    /// @return _resultTimestamp Timestamp at which the query was solved by the Witnet blockchain.
    /// @return _resultDrTxHash Witnet blockchain hash of the commit/reveal act that solved the query.
    function checkResultTraceability(uint256 _queryId) external view returns (uint256 _resultTimestamp, bytes32 _resultDrTxHash);

    /// @notice Retrieves a copy of all Witnet-provided data related to a previously posted request, removing the whole query from the WRB storage.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param _queryId The unique query identifier.
    function deleteQuery(uint256 _queryId) external returns (Witnet.Response memory);

    /// @notice Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// @notice A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// @notice result to this request.
    /// @dev Fails if provided reward is too low.
    /// @dev The result to the query will be saved into the WitnetRequestBoard storage.
    /// @param radHash The RAD hash of the data request to be solved by Witnet.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @return _queryId Unique query identifier.
    function postRequest(bytes32 radHash, Witnet.RadonSLA calldata querySLA) external payable returns (uint256 _queryId);

    /// @notice Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// @notice A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// @notice result to this request.
    /// @dev Fails if, provided reward is too low.
    /// @dev The caller must be a contract implementing the IWitnetConsumer interface.
    /// @param radHash The RAD hash of the data request to be solved by Witnet.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @return _queryId Unique query identifier.
    function postRequestWithCallback(bytes32 radHash, Witnet.RadonSLA calldata querySLA, uint256 maxCallbackGas) external payable returns (uint256 _queryId);

    /// @notice Increments the reward of a previously posted request by adding the transaction value to it.
    /// @param _queryId The unique query identifier.
    function upgradeQueryReward(uint256 _queryId) external payable;
  

    /// ===============================================================================================================
    /// --- Reader interface ------------------------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).  
    function estimateBaseFee(uint256 _gasPrice, uint256 _resultMaxSize) external view returns (uint256);
    
    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _maxCallbackGas Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _gasPrice, uint256 _maxCallbackGas) external view returns (uint256);

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
    function getQueryRequest(uint256 _queryId) external view returns (Witnet.Request memory);

    /// @notice Retrieves the serialized bytecode of a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not valid, or if the related script bytecode 
    /// @dev got changed after being posted. Returns empty array once it gets reported, 
    /// @dev or deleted.
    /// @param _queryId The unique query identifier.
    function getQueryRequestBytecode(uint256 _queryId) external view returns (bytes memory);
    
    /// @notice Retrieves the whole `Witnet.Response` record referred to a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function getQueryResponse(uint256 _queryId) external view returns (Witnet.Response memory);

    /// @notice Retrieves the reward currently set for the referred query.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been 
    /// @dev reported, or deleted. 
    /// @param _queryId The unique query identifier.
    function getQueryReward(uint256 _queryId) external view returns (uint256);

    /// @notice Retrieves the Witnet-provided CBOR-bytes result of a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status.
    /// @param _queryId The unique query identifier.
    function getQueryResponseResult(uint256 _queryId) external view returns (Witnet.Result memory);


}
