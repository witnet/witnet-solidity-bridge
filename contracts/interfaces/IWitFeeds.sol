// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitOracle.sol";
import "../WitOracleRadonRegistry.sol";

interface IWitFeeds {

    struct UpdateSLA {
        // Max number of eligibile witnesses in the Wit/Oracle blockchain for solving some price update.
        uint16 witCommitteeSize;
        // Minimum expenditure in nanoWits for getting the price update solved and reported from the Wit/Oracle.
        uint64 witInclusionFees;
    }

    /// Primitive data type produced by successful data updates of all supported
    /// feeds (e.g. Witnet.RadonDataTypes.Integer in WitPriceFeeds).
    function dataType() external view returns (Witnet.RadonDataTypes);

    /// ERC-2362 caption prefix shared by all supported feeds (e.g. "Price-" in WitPriceFeeds).
    function prefix() external view returns (string memory);
    
    /// Default SLA data security parameters that will be fulfilled on Witnet upon 
    /// every feed update, if no others are specified by the requester.
    function defaultUpdateSLA() external view returns (UpdateSLA memory);

    /// Estimates the minimum EVM fee required to be paid upon requesting a data 
    /// update with the given the _evmGasPrice value.
    function estimateUpdateRequestFee(uint256 evmGasPrice) external view returns (uint);

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint() external view returns (bytes4);

    /// This pure function determines the ERC-2362 identifier of the given data feed 
    /// caption string, truncated to bytes4.
    function hash(string calldata caption) external pure returns (bytes4);

    /// Returns the query id (in the context of the WitOracle addressed by witOracle()) 
    /// that solved the most recently updated value for the given feed.
    function lastValidQueryId(bytes4 feedId) external view returns (Witnet.QueryId);

    /// Returns the actual response from the Witnet oracle blockchain to the last 
    /// successful update for the given data feed.
    function lastValidQueryResponse(bytes4 feedId) external view returns (Witnet.QueryResponse memory);

    /// Returns the Witnet query id of the latest update attempt for the given data feed.
    function latestUpdateQueryId(bytes4 feedId) external view returns (Witnet.QueryId);

    /// Returns the actual request queried to the the Witnet oracle blockchain on the latest 
    /// update attempt for the given data feed.
    function latestUpdateQueryRequest(bytes4 feedId) external view returns (Witnet.QueryRequest memory);

    /// Returns the response from the Witnet oracle blockchain to the latest update attempt 
    /// for the given data feed.
    function latestUpdateQueryResult(bytes4 feedId) external view returns (Witnet.DataResult memory);

    /// Tells the current response status of the latest update attempt for the given data feed.
    function latestUpdateQueryResultStatus(bytes4 feedId) external view returns (Witnet.ResultStatus);

    /// Describes the error returned from the Witnet oracle blockchain in response to the latest 
    /// update attempt for the given data feed, if any.
    function latestUpdateQueryResultStatusDescription(bytes4 feedId) external view returns (string memory);
    
    /// Returns the ERC-2362 caption of the given feed identifier, if known. 
    function lookupCaption(bytes4) external view returns (string memory);

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
    function requestUpdate(bytes4 feedId, UpdateSLA calldata) external payable returns (uint256 usedFunds);

    /// Returns the list of feed ERC-2362 ids, captions and RAD hashes of all currently supported 
    /// data feeds. The RAD hash of a data feed determines in a verifiable way the actual data sources 
    /// and off-chain computations solved by the Witnet oracle blockchain upon every data update. 
    /// The RAD hash value for a routed feed actually contains the address of the IWitnetPriceSolver 
    /// logic contract that solves it.
    function supportedFeeds() external view returns (bytes4[] memory, string[] memory, bytes32[] memory);

    /// Tells whether the given ERC-2362 feed caption is currently supported.
    function supportsCaption(string calldata) external view returns (bool);

    /// Total number of data feeds, routed or not, that are currently supported.
    function totalFeeds() external view returns (uint256);
}
