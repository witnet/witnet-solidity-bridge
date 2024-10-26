// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./IWitOracleConsumer.sol";

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
    /// @param callbackGas Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 evmGasPrice, uint24 callbackGas) external view returns (uint256);

    /// @notice Estimate the extra reward (i.e. over the base fee) to be paid when posting a new
    /// @notice data query in order to avoid getting provable "too low incentives" results from
    /// @notice the Wit/oracle blockchain. 
    /// @dev The extra fee gets calculated in proportion to:
    /// @param evmGasPrice Tentative EVM gas price at the moment the query result is ready.
    /// @param evmWitPrice  Tentative nanoWit price in Wei at the moment the query is solved on the Wit/oracle blockchain.
    /// @param querySLA The query SLA data security parameters as required for the Wit/oracle blockchain. 
    function estimateExtraFee(uint256 evmGasPrice, uint256 evmWitPrice, Witnet.QuerySLA calldata querySLA) external view returns (uint256);
    
    // /// @notice Returns the address of the WitOracleRequestFactory appliance capable of building compliant data request
    // /// @notice templates verified into the same WitOracleRadonRegistry instance returned by registry().
    // function factory() external view returns (WitOracleRequestFactory);
       
    /// @notice Retrieves a copy of all Witnet-provable data related to a previously posted request, 
    /// removing the whole query from the WRB storage.
    /// @dev Fails if the query was not in 'Reported' status, or called from an address different to
    /// @dev the one that actually posted the given request.
    /// @param queryId The unique query identifier.
    function fetchQueryResponse(Witnet.QueryId queryId) external returns (Witnet.QueryResponse memory);
   
    /// @notice Gets the whole Query data contents, if any, no matter its current status.
    function getQuery(Witnet.QueryId queryId) external view returns (Witnet.Query memory);

    /// @notice Gets the current EVM reward the report can claim, if not done yet.
    function getQueryEvmReward(Witnet.QueryId) external view returns (Witnet.QueryReward);

    /// @notice Retrieves the RAD hash and SLA parameters of the given query.
    function getQueryRequest(Witnet.QueryId) external view returns (Witnet.QueryRequest memory);

    /// @notice Retrieves the whole `Witnet.QueryResponse` record referred to a previously posted Witnet Data Request.
    function getQueryResponse(Witnet.QueryId) external view returns (Witnet.QueryResponse memory);

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query response was finalized, and contains a result with no erros.
    /// @notice   - 3 => Error: the query response was finalized, and contains a result with errors.
    /// @notice   - 4 => Finalizing: some result to the query has been reported, but cannot yet be considered finalized.
    /// @notice   - 5 => Delivered: at least one response, either successful or with errors, was delivered to the requesting contract.
    function getQueryResponseStatus(Witnet.QueryId) external view returns (Witnet.QueryResponseStatus);
    function getQueryResponseStatusTag(Witnet.QueryId) external view returns (string memory);

    /// @notice Retrieves the CBOR-encoded buffer containing the Witnet-provided result to the given query.
    function getQueryResultCborBytes(Witnet.QueryId) external view returns (bytes memory);

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    function getQueryResultError(Witnet.QueryId) external view returns (Witnet.ResultError memory);

    /// @notice Gets current status of given query.
    function getQueryStatus(Witnet.QueryId) external view returns (Witnet.QueryStatus);
    function getQueryStatusTag(Witnet.QueryId) external view returns (string memory);
    
    /// @notice Get current status of all given query ids.
    function getQueryStatusBatch(Witnet.QueryId[] calldata) external view returns (Witnet.QueryStatus[] memory);

    /// @notice Returns next query id to be generated by the Witnet Request Board.
    function getNextQueryId() external view returns (Witnet.QueryId);

    /// @notice Request real world data from the Wit/oracle sidechain. 
    /// @notice The paid fee is escrowed as a reward for the reporter that eventually relays back 
    /// @notice a valid query result from the Wit/oracle sidechain.
    /// @notice Query results are CBOR-encoded, and can contain either some data, or an error.
    /// @dev Reasons to revert:
    /// @dev - the data request's RAD hash was not previously verified into the WitOracleRadonRegistry contract;
    /// @dev - invalid query SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @param drRadHash The RAD hash of the data request to be solved by Wit/oracle sidechain. 
    function postQuery(bytes32 drRadHash, Witnet.QuerySLA calldata)
        external payable returns (Witnet.QueryId);

    /// @notice Request real world data from the Wit/oracle sidechain. 
    /// @notice The paid fee is escrowed as a reward for the reporter that eventually relays back 
    /// @notice a valid query result from the Wit/oracle sidechain.
    /// @notice The Witnet-provable result will be reported directly to the requesting contract. 
    /// @notice Query results are CBOR-encoded, and can contain either some data, or an error.
    /// @dev Reasons to revert:
    /// @dev - the data request's RAD hash was not previously verified into the Radon Registry;
    /// @dev - invalid query SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @dev - passed `consumer` is not a contract implementing the IWitOracleConsumer interface;
    /// @param drRadHash The RAD hash of the data request to be solved by Wit/oracle sidechain.
    function postQuery(bytes32 drRadHash, Witnet.QuerySLA calldata, Witnet.QueryCallback calldata)
        external payable returns (Witnet.QueryId);

    /// @notice Request real world data from the Wit/oracle sidechain. 
    /// @notice The paid fee is escrowed as a reward for the reporter that eventually relays back 
    /// @notice a valid query result from the Wit/oracle sidechain.
    /// @notice The Witnet-provable result will be reported directly to the requesting contract. 
    /// @notice Query results are CBOR-encoded, and can contain either some data, or an error.
    /// @dev Reasons to revert:
    /// @dev - the data request's RAD hash was not previously verified into the Radon Registry;
    /// @dev - invalid query SLA parameters were provided;
    /// @dev - insufficient value is paid as reward.
    /// @dev - passed `consumer` is not a contract implementing the IWitOracleConsumer interface;
    /// @param drBytecode Encoded witnet-compliant script describing how and where to retrieve data from.
    function postQuery(bytes calldata drBytecode, Witnet.QuerySLA calldata, Witnet.QueryCallback calldata)
        external payable returns (Witnet.QueryId);

    /// @notice Returns the singleton WitOracleRadonRegistry in which all Witnet-compliant data requests 
    /// @notice and templates must be previously verified so they can be passed as reference when 
    /// @notice calling postRequest(bytes32,..) methods.
    function registry() external view returns (WitOracleRadonRegistry);

    /// @notice Enables data requesters to settle the actual validators in the Wit/oracle
    /// @notice sidechain that will be entitled to solve data requests requiring to
    /// @notice support some given `Wit2.Capability`.
    function settleMyOwnCapableCommittee(Witnet.QueryCapability, Witnet.QueryCapabilityMember[] calldata) external;

    /// @notice Increments the reward of a previously posted request by adding the transaction value to it.
    function upgradeQueryEvmReward(Witnet.QueryId) external payable;
}
