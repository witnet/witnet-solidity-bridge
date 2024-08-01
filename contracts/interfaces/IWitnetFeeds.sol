// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitnetOracle.sol";
import "../WitnetRadonRegistry.sol";

interface IWitnetFeeds {   

    /// Primitive data type produced by successful data updates of all supported
    /// feeds (e.g. Witnet.RadonDataTypes.Integer in WitnetPriceFeeds).
    function dataType() external view returns (Witnet.RadonDataTypes);

    /// ERC-2362 caption prefix shared by all supported feeds (e.g. "Price-" in WitnetPriceFeeds).
    function prefix() external view returns (string memory);
    
    /// Default SLA data security parameters that will be fulfilled on Witnet upon 
    /// every feed update, if no others are specified by the requester.
    function defaultRadonSLA() external view returns (Witnet.RadonSLA memory);

    /// Estimates the minimum EVM fee required to be paid upon requesting a data 
    /// update with the given the _evmGasPrice value.
    function estimateUpdateRequestFee(uint256 evmGasPrice) external view returns (uint);

    /// Returns the query id (in the context of the WitnetOracle addressed by witnet()) 
    /// that solved the most recently updated value for the given feed.
    function lastValidQueryId(bytes4 feedId) external view returns (uint256);

    /// Returns the actual response from the Witnet oracle blockchain to the last 
    /// successful update for the given data feed.
    function lastValidResponse(bytes4 feedId) external view returns (Witnet.Response memory);

    /// Returns the Witnet query id of the latest update attempt for the given data feed.
    function latestUpdateQueryId(bytes4 feedId) external view returns (uint256);

    /// Returns the actual request queried to the the Witnet oracle blockchain on the latest 
    /// update attempt for the given data feed.
    function latestUpdateRequest(bytes4 feedId) external view returns (Witnet.Request memory);

    /// Returns the response from the Witnet oracle blockchain to the latest update attempt 
    /// for the given data feed.
    function latestUpdateResponse(bytes4 feedId) external view returns (Witnet.Response memory);

    /// Tells the current response status of the latest update attempt for the given data feed.
    function latestUpdateResponseStatus(bytes4 feedId) external view returns (Witnet.ResponseStatus);

    /// Describes the error returned from the Witnet oracle blockchain in response to the latest 
    /// update attempt for the given data feed, if any.
    function latestUpdateResultError(bytes4 feedId) external view returns (Witnet.ResultError memory);
    
    /// Returns the Witnet-compliant bytecode of the data retrieving script to be solved by 
    /// the Witnet oracle blockchain upon every update of the given data feed.
    function lookupWitnetBytecode(bytes4 feedId) external view returns (bytes memory);

    /// Returns the RAD hash that uniquely identifies the data retrieving script that gets solved 
    /// by the Witnet oracle blockchain upon every update of the given data feed.
    function lookupWitnetRadHash(bytes4 feedId) external view returns (bytes32);

    /// Returns the list of actual data sources and offchain computations for the given data feed.
    function lookupWitnetRetrievals(bytes4 feedId) external view returns (Witnet.RadonRetrieval[] memory);

    /// Triggers a fresh update on the Witnet oracle blockchain for the given data feed, 
    /// using the defaultRadonSLA() security parameters.
    function requestUpdate(bytes4 feedId) external payable returns (uint256 usedFunds);

    /// Triggers a fresh update for the given data feed, requiring also the SLA data security parameters
    /// that will have to be fulfilled on Witnet. 
    function requestUpdate(bytes4 feedId, Witnet.RadonSLA calldata updateSLA) external payable returns (uint256 usedFunds);
}
