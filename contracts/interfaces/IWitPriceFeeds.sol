// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./legacy/IWitPyth.sol";

interface IWitPriceFeeds is IWitPyth {

    struct Info {
        bytes32 id;
        string symbol;
        int8 exponent;
        SLA params;
    }

    struct SLA {
        uint24 heartbeatSecs;
        uint16 deviation1000;
    }

    struct WitParams {
        uint16 witCommitteeSize;
        uint64 witInclusionFees;
    }

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint() external view returns (bytes4);
    
    function hash(string calldata symbol) external pure returns (bytes32);
    
    function lookupExponent(bytes32 id) external view returns (int8);
    function lookupMappingSolver(bytes32 id) external view returns (address, bytes32[] memory);
    function lookupRadonBytecode(bytes32 id) external view returns (bytes memory);
    function lookupRadonHash(bytes32 id) external view returns (Witnet.RadonHash);
    function lookupRadonRequest(bytes32 id) external view returns (Witnet.RadonRequest memory);
    function lookupSLA(bytes32 id) external view returns (SLA memory);
    function lookupSymbol(bytes32 id) external view returns (string memory);

    function supportedPriceFeeds() external view returns (Info[] memory);
    function supportsPriceFeed(string calldata symbol) external view returns (bool);

    function getUpdateWitParams() external view returns (WitParams memory);
    
    function createChainlinkAggregator(bytes32 id) external returns (address);
    function determineChainlinkAggregatorAddress(bytes32 id) external view returns (address);
}
