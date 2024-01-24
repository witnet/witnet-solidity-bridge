// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../../libs/WitnetV2.sol";

interface IWitnetRequestBoard {

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `resultMaxSize`. 
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param resultMaxSize Maximum expected size of returned data (in bytes).  
    function estimateBaseFee(uint256 gasPrice, uint16 resultMaxSize) external view returns (uint256);

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Fails if the RAD hash was not previously verified on the WitnetBytecodes registry.
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param radHash The RAD hash of the data request to be solved by Witnet.
    function estimateBaseFee(uint256 gasPrice, bytes32 radHash) external view returns (uint256);
    
    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 gasPrice, uint96 callbackGasLimit) external view returns (uint256);
       
    /// @notice Retrieves a copy of all Witnet-provable data related to a previously posted request, 
    /// removing the whole query from the WRB storage.
    /// @dev Fails if the query was not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param queryId The unique query identifier.
    function fetchQueryResponse(uint256 queryId) external returns (WitnetV2.Response memory);
   
    /// @notice Gets the whole Query data contents, if any, no matter its current status.
    function getQuery(uint256 queryId) external view returns (WitnetV2.Query memory);

    /// @notice Retrieves the serialized bytecode of a previously posted Witnet Data Request.
    /// @dev Fails if the query does not exist.
    /// @param queryId The unique query identifier.
    function getQueryBytecode(uint256 queryId) external view returns (bytes memory);

    /// @notice Retrieves the RAD hash and SLA parameters of the given query.
    /// @param queryId The unique query identifier.
    function getQueryRequest(uint256 queryId) external view returns (bytes32, WitnetV2.RadonSLA memory);

    /// @notice Retrieves the whole `Witnet.Response` record referred to a previously posted Witnet Data Request.
    /// @param queryId The unique query identifier.
    function getQueryResponse(uint256 queryId) external view returns (WitnetV2.Response memory);

    /// @notice Retrieves the Witnet-provable CBOR-bytes result of a previously posted request.
    /// @param queryId The unique query identifier.
    function getQueryResult(uint256 queryId) external view returns (Witnet.Result memory);

    /// @notice Returns reference to the commit/reveal act that took place on the Witnet blockchain.
    /// @param queryId The unique query identifier.
    /// @return witnetTimestamp Timestamp at which the query was solved by the Witnet blockchain.
    /// @return witnetTallyHash Hash of the commit/reveal act that solved the query on the Witnet blockchain.
    /// @return witnetEvmFinalityBlock EVM block at which the provided data can be considered to be final.
    function getQueryResultAuditTrail(uint256 queryId) external view returns (
            uint256 witnetTimestamp, 
            bytes32 witnetTallyHash,
            uint256 witnetEvmFinalityBlock
        );

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param queryId The unique query identifier.
    function getQueryResultError(uint256 queryId) external view returns (Witnet.ResultError memory);

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query response was finalized, and contains a result with no erros.
    /// @notice   - 3 => Error: the query response was finalized, and contains a result with errors.
    /// @param queryId The unique query identifier.
    function getQueryResultStatus(uint256 queryId) external view returns (WitnetV2.ResultStatus);

    /// @notice Retrieves the reward currently set for the referred query.
    /// @dev Fails if the `queryId` is not valid or, if it has already been reported, delivered, or deleted. 
    /// @param queryId The unique query identifier.
    function getQueryReward(uint256 queryId) external view returns (uint256);

    /// @notice Gets current status of given query.
    function getQueryStatus(uint256 queryId) external view returns (WitnetV2.QueryStatus);

    // /// @notice Returns next query id to be generated by the Witnet Request Board.
    // function getNextQueryId() external view returns (uint256);

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and 
    /// @notice solved by the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be 
    /// @notice transferred to the reporter who relays back the Witnet-provable result to this request.
    /// @dev Reasons to fail:
    /// @dev - the RAD hash was not previously verified by the WitnetBytecodes registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @return queryId Unique query identifier.
    function postRequest(
            bytes32 queryRAD, 
            WitnetV2.RadonSLA calldata querySLA
        ) external payable returns (uint256 queryId);

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, an `WitnetResponseDeliveryFailed`
    /// @notice will be triggered, and the Witnet audit trail will be saved in storage, but not so the actual CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitnetConsumer interface;
    /// @dev - the RAD hash was not previously verified by the WitnetBytecodes registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    /// @return queryId Unique query identifier.
    function postRequestWithCallback(
            bytes32 queryRAD, 
            WitnetV2.RadonSLA calldata querySLA, 
            uint96 queryCallbackGasLimit
        ) external payable returns (uint256 queryId);

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, a `WitnetResponseDeliveryFailed`
    /// @notice event will be triggered, and the Witnet audit trail will be saved in storage, but not so the CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitnetConsumer interface;
    /// @dev - the provided bytecode is empty;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param queryUnverifiedBytecode The (unverified) bytecode containing the actual data request to be solved by the Witnet blockchain.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    /// @return queryId Unique query identifier.
    function postRequestWithCallback(
            bytes calldata queryUnverifiedBytecode,
            WitnetV2.RadonSLA calldata querySLA, 
            uint96 queryCallbackGasLimit
        ) external payable returns (uint256 queryId);

    /// @notice Increments the reward of a previously posted request by adding the transaction value to it.
    /// @param queryId The unique query identifier.
    function upgradeQueryReward(uint256 queryId) external payable;

}
