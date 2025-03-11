// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleLegacy.sol";
import "./IWitPriceFeedsLegacySolver.sol";

interface IWitPriceFeedsLegacy {   

    /// A fresh update on the data feed identified as `erc2364Id4` has just been 
    /// requested and paid for by some `evmSender`, under command of the 
    /// `evmOrigin` externally owned account. 
    event PullingUpdate(
        address evmOrigin,
        address evmSender,
        bytes4  erc2362Id4,
        Witnet.QueryId witOracleQueryId
    );

    struct RadonSLA {
        uint8  numWitnesses;
        uint64 unitaryReward;
    }

    /// Primitive data type produced by successful data updates of all supported
    /// feeds (e.g. Witnet.RadonDataTypes.Integer in WitPriceFeeds).
    function dataType() external view returns (Witnet.RadonDataTypes);
    
    function defaultRadonSLA() external view returns (RadonSLA memory);

    function estimateUpdateBaseFee(uint256 evmGasPrice) external view returns (uint);

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

    function latestPrice(bytes4 feedId) external view returns (IWitPriceFeedsLegacySolver.Price memory);
    function latestPrices(bytes4[] calldata feedIds)  external view returns (IWitPriceFeedsLegacySolver.Price[] memory);

    /// Returns the Witnet query id of the latest update attempt for the given data feed.
    function latestUpdateQueryId(bytes4 feedId) external view returns (Witnet.QueryId);

    /// Returns the actual request queried to the the Witnet oracle blockchain on the latest 
    /// update attempt for the given data feed.
    function latestUpdateQueryRequest(bytes4 feedId) external view returns (Witnet.QueryRequest memory);

    function latestUpdateResponse(bytes4 feedId) external view returns (Witnet.QueryResponse memory);
    function latestUpdateResponseStatus(bytes4 feedId) external view returns (IWitOracleLegacy.QueryResponseStatus);
    function latestUpdateResultError(bytes4 feedId) external view returns (IWitOracleLegacy.ResultError memory);

    /// Returns the ERC-2362 caption of the given feed identifier, if known. 
    function lookupCaption(bytes4) external view returns (string memory);

    function lookupDecimals(bytes4 feedId) external view returns (uint8);    
    function lookupPriceSolver(bytes4 feedId) external view returns (
            address solverAddress, 
            string[] memory solverDeps
        );
    
    function lookupWitnetBytecode(bytes4) external view returns (bytes memory);
    function lookupWitnetRadHash(bytes4) external view returns (bytes32);
    function lookupWitnetRetrievals(bytes4) external view returns (Witnet.RadonRetrieval[] memory);
    
    /// ERC-2362 caption prefix shared by all supported feeds (e.g. "Price-" in WitPriceFeeds).
    function prefix() external view returns (string memory);
    
    /// Triggers a fresh update on the Witnet oracle blockchain for the given data feed, 
    /// using the defaultRadonSLA() security parameters.
    function requestUpdate(bytes4 feedId) external payable returns (uint256 usedFunds);
    function requestUpdate(bytes4, RadonSLA calldata) external payable returns (uint256 usedFunds);

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

    function witnet() external view returns (address);
}
