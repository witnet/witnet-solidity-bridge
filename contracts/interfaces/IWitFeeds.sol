// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitOracle.sol";
import "../WitOracleRadonRegistry.sol";

interface IWitFeeds {   

    /// Primitive data type produced by successful data updates of all supported
    /// feeds (e.g. Witnet.RadonDataTypes.Integer in WitPriceFeeds).
    function dataType() external view returns (Witnet.RadonDataTypes);

    /// ERC-2362 caption prefix shared by all supported feeds (e.g. "Price-" in WitPriceFeeds).
    function prefix() external view returns (string memory);
    
    /// Default SLA data security parameters that will be fulfilled on Witnet upon 
    /// every feed update, if no others are specified by the requester.
    function defaultRadonSLA() external view returns (Witnet.RadonSLA memory);

    /// Estimates the minimum EVM fee required to be paid upon requesting a data 
    /// update with the given the _evmGasPrice value.
    function estimateUpdateRequestFee(uint256 evmGasPrice) external view returns (uint);

    /// Returns the query id (in the context of the WitOracle addressed by witnet()) 
    /// that solved the most recently updated value for the given feed.
    function lastValidQueryId(bytes4 feedId) external view returns (uint256);

    /// Returns the actual response from the Witnet oracle blockchain to the last 
    /// successful update for the given data feed.
    function lastValidQueryResponse(bytes4 feedId) external view returns (Witnet.QueryResponse memory);

    /// Returns the Witnet query id of the latest update attempt for the given data feed.
    function latestUpdateQueryId(bytes4 feedId) external view returns (uint256);

    /// Returns the actual request queried to the the Witnet oracle blockchain on the latest 
    /// update attempt for the given data feed.
    function latestUpdateQueryRequest(bytes4 feedId) external view returns (Witnet.QueryRequest memory);

    /// Returns the response from the Witnet oracle blockchain to the latest update attempt 
    /// for the given data feed.
    function latestUpdateQueryResponse(bytes4 feedId) external view returns (Witnet.QueryResponse memory);

    /// Tells the current response status of the latest update attempt for the given data feed.
    function latestUpdateQueryResponseStatus(bytes4 feedId) external view returns (Witnet.QueryResponseStatus);

    /// Describes the error returned from the Witnet oracle blockchain in response to the latest 
    /// update attempt for the given data feed, if any.
    function latestUpdateResultError(bytes4 feedId) external view returns (Witnet.ResultError memory);
    
    /// Returns the Witnet-compliant bytecode of the data retrieving script to be solved by 
    /// the Witnet oracle blockchain upon every update of the given data feed.
    function lookupWitOracleRequestBytecode(bytes4 feedId) external view returns (bytes memory);

    /// Returns the RAD hash that uniquely identifies the data retrieving script that gets solved 
    /// by the Witnet oracle blockchain upon every update of the given data feed.
    function lookupWitOracleRequestRadHash(bytes4 feedId) external view returns (bytes32);

    /// Returns the list of actual data sources and offchain computations for the given data feed.
    function lookupWitOracleRadonRetrievals(bytes4 feedId) external view returns (Witnet.RadonRetrieval[] memory);

    /// Triggers a fresh update on the Witnet oracle blockchain for the given data feed, 
    /// using the defaultRadonSLA() security parameters.
    function requestUpdate(bytes4 feedId) external payable returns (uint256 usedFunds);

    /// Triggers a fresh update for the given data feed, requiring also the SLA data security parameters
    /// that will have to be fulfilled on Witnet. 
    function requestUpdate(bytes4 feedId, Witnet.RadonSLA calldata updateSLA) external payable returns (uint256 usedFunds);
}
