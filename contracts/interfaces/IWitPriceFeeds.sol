// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPriceFeedsMappingSolver.sol";
import "./legacy/IWitPyth.sol";
import "./legacy/IWitPythChainlinkAggregator.sol";

interface IWitPriceFeeds is IWitPyth {

    struct Info {
        Id id;
        int8 exponent;
        Witnet.RadonHash sources;
        string symbol;
    }

    struct UpdateConditions {
        uint16 deviation1000;
        uint24 heartbeatSecs;
    }

    struct WitParams {
        uint16 witCommitteeSize;
        uint16 witInclusionFees;
    }

    function createChainlinkAggregator(Id id) external returns (IWitPythChainlinkAggregator);
    function determineChainlinkAggregatorAddress(Id id) external view returns (address);

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint() external view returns (bytes4);
    function hash(string calldata symbol) external pure returns (Id);
    
    function lookupPriceFeed(Id id) external view returns (Info memory);
    function lookupPriceFeedSolver(Id id) external view returns (IWitPriceFeedsMappingSolver, Id[] memory);
    function lookupPriceFeedUpdateConditions(Id id) external view returns (UpdateConditions memory);
    function lookupSymbol(Id id) external view returns (string memory);

    function supportedPriceFeeds() external view returns (Info[] memory);
    function supportsPriceFeed(string calldata symbol) external view returns (bool);

    function witOracleRequiredParams() external view returns (WitParams memory);
}
