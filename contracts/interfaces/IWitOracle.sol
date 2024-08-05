// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

import "../WitOracleRadonRegistry.sol";
import "../WitOracleRequestFactory.sol";

interface IWitOracle {

    /// @notice Uniquely identifies the WitOracle addrees and the chain on which it's deployed.
    function channel() external view returns (bytes4);

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @param evmGasPrice Expected gas price to pay upon posting the data request.
    function estimateBaseFee(uint256 evmGasPrice) external view returns (uint256);
    
    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param evmGasPrice Expected gas price to pay upon posting the data request.
    /// @param callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 evmGasPrice, uint24 callbackGasLimit) external view returns (uint256);

    /// @notice Estimate the extra reward (i.e. over the base fee) to be paid when posting a new
    /// @notice data query in order to avoid getting provable "too low incentives" results from
    /// @notice the Wit/oracle blockchain. 
    /// @dev The extra fee gets calculated in proportion to:
    /// @param evmGasPrice Tentative EVM gas price at the moment the query result is ready.
    /// @param evmWitPrice  Tentative nanoWit price in Wei at the moment the query is solved on the Wit/oracle blockchain.
    /// @param querySLA The query SLA data security parameters as required for the Wit/oracle blockchain. 
    function estimateExtraFee(uint256 evmGasPrice, uint256 evmWitPrice, Witnet.RadonSLA calldata querySLA) external view returns (uint256);
    
    /// @notice Returns the address of the WitOracleRequestFactory appliance capable of building compliant data request
    /// @notice templates verified into the same WitOracleRadonRegistry instance returned by registry().
    function factory() external view returns (WitOracleRequestFactory);
       
    /// @notice Retrieves a copy of all Witnet-provable data related to a previously posted request, 
    /// removing the whole query from the WRB storage.
    /// @dev Fails if the query was not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param queryId The unique query identifier.
    function fetchQueryResponse(uint256 queryId) external returns (Witnet.QueryResponse memory);
   
    /// @notice Gets the whole Query data contents, if any, no matter its current status.
    function getQuery(uint256 queryId) external view returns (Witnet.Query memory);

    /// @notice Gets the current EVM reward the report can claim, if not done yet.
    function getQueryEvmReward(uint256 queryId) external view returns (uint256);

    /// @notice Retrieves the RAD hash and SLA parameters of the given query.
    /// @param queryId The unique query identifier.
    function getQueryRequest(uint256 queryId) external view returns (Witnet.QueryRequest memory);

    /// @notice Retrieves the whole `Witnet.QueryResponse` record referred to a previously posted Witnet Data Request.
    /// @param queryId The unique query identifier.
    function getQueryResponse(uint256 queryId) external view returns (Witnet.QueryResponse memory);

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query response was finalized, and contains a result with no erros.
    /// @notice   - 3 => Error: the query response was finalized, and contains a result with errors.
    /// @notice   - 4 => Finalizing: some result to the query has been reported, but cannot yet be considered finalized.
    /// @notice   - 5 => Delivered: at least one response, either successful or with errors, was delivered to the requesting contract.
    /// @param queryId The unique query identifier.
    function getQueryResponseStatus(uint256 queryId) external view returns (Witnet.QueryResponseStatus);

    /// @notice Retrieves the CBOR-encoded buffer containing the Witnet-provided result to the given query.
    /// @param queryId The unique query identifier.
    function getQueryResultCborBytes(uint256 queryId) external view returns (bytes memory);

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param queryId The unique query identifier.
    function getQueryResultError(uint256 queryId) external view returns (Witnet.ResultError memory);

    /// @notice Gets current status of given query.
    function getQueryStatus(uint256 queryId) external view returns (Witnet.QueryStatus);
    
    /// @notice Get current status of all given query ids.
    function getQueryStatusBatch(uint256[] calldata queryIds) external view returns (Witnet.QueryStatus[] memory);

    /// @notice Returns next query id to be generated by the Witnet Request Board.
    function getNextQueryId() external view returns (uint256);

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and 
    /// @notice solved by the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be 
    /// @notice transferred to the reporter who relays back the Witnet-provable result to this request.
    /// @dev Reasons to fail:
    /// @dev - the RAD hash was not previously verified by the WitOracleRadonRegistry registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @return queryId Unique query identifier.
    function postRequest(
            bytes32 queryRAD, 
            Witnet.RadonSLA calldata querySLA
        ) external payable returns (uint256 queryId);

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, an `WitnetQueryResponseDeliveryFailed`
    /// @notice will be triggered, and the Witnet audit trail will be saved in storage, but not so the actual CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitOracleConsumer interface;
    /// @dev - the RAD hash was not previously verified by the WitOracleRadonRegistry registry;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param queryRAD The RAD hash of the data request to be solved by Witnet.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    /// @return queryId Unique query identifier.
    function postRequestWithCallback(
            bytes32 queryRAD, 
            Witnet.RadonSLA calldata querySLA, 
            uint24 queryCallbackGasLimit
        ) external payable returns (uint256 queryId);

            // function postRequestWithCallbackFrom(
            //     address consumer,
            //     bytes32 queryRAD, 
            //     Witnet.RadonSLA calldata querySLA, 
            //     uint24 queryCallbackGasLimit
            // ) external payable returns (uint256 queryId);

    /// @notice Requests the execution of the given Witnet Data Request, in expectation that it will be relayed and solved by 
    /// @notice the Witnet blockchain. A reward amount is escrowed by the Witnet Request Board that will be transferred to the 
    /// @notice reporter who relays back the Witnet-provable result to this request. The Witnet-provable result will be reported
    /// @notice directly to the requesting contract. If the report callback fails for any reason, a `WitnetQueryResponseDeliveryFailed`
    /// @notice event will be triggered, and the Witnet audit trail will be saved in storage, but not so the CBOR-encoded result.
    /// @dev Reasons to fail:
    /// @dev - the caller is not a contract implementing the IWitOracleConsumer interface;
    /// @dev - the provided bytecode is empty;
    /// @dev - invalid SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param queryUnverifiedBytecode The (unverified) bytecode containing the actual data request to be solved by the Witnet blockchain.
    /// @param querySLA The data query SLA to be fulfilled on the Witnet blockchain.
    /// @param queryCallbackGasLimit Maximum gas to be spent when reporting the data request result.
    /// @return queryId Unique query identifier.
    function postRequestWithCallback(
            bytes calldata queryUnverifiedBytecode,
            Witnet.RadonSLA calldata querySLA, 
            uint24 queryCallbackGasLimit
        ) external payable returns (uint256 queryId);    


        // function postRequestWithCallbackFrom(
        //         address consumer,
        //         bytes calldata queryUnverifiedBytecode,
        //         Witnet.RadonSLA calldata querySLA, 
        //         uint24 queryCallbackGasLimit
        //     ) external payable returns (uint256 queryId);    

    /// @notice Returns the singleton WitOracleRadonRegistry in which all Witnet-compliant data requests 
    /// @notice and templates must be previously verified so they can be passed as reference when 
    /// @notice calling postRequest(bytes32,..) methods.
    function registry() external view returns (WitOracleRadonRegistry);

    /// @notice Increments the reward of a previously posted request by adding the transaction value to it.
    /// @param queryId The unique query identifier.
    function upgradeQueryEvmReward(uint256 queryId) external payable;

}
