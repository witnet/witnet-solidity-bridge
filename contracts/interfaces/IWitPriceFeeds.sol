// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IWitPriceFeedsAdmin} from "./IWitPriceFeedsAdmin.sol";
import {IWitPriceFeedsConsumer} from "./IWitPriceFeedsConsumer.sol";
import {IWitPriceFeedsEvents} from "./IWitPriceFeedsEvents.sol";
import {IWitPriceFeedsTypes} from "./IWitPriceFeedsTypes.sol";
import {IWitPyth} from "./legacy/IWitPyth.sol";

import {Witnet} from "../libs/Witnet.sol";

interface IWitPriceFeeds
    is
        IWitPriceFeedsAdmin,
        IWitPriceFeedsEvents, 
        IWitPriceFeedsTypes,
        IWitPyth
{
    /// Address of the underlying logic contract.
    function base() external view returns (address);

    /// Creates a light-proxy clone to the `base()` contract address, to be owned by the specified `curator` address. 
    /// Curators of cloned contracts can optionally settle one single `IWitPriceFeedConsumer` consuming contract. 
    /// The consuming contract, if settled, will be immediately reported every time a new Witnet-certified price update
    /// gets pushed into the cloned instance. Either way, price feeds data will be stored in the `WitPriceFeeds` storage. 
    /// @param curator Address that will have rights to manage price feeds on the new light-proxy clone.
    function clone(address curator) external returns (address);

    /// Determines the unique 4-byte ID4 for the specified caption.
    function computeID4(string calldata caption) external pure returns (ID4);

    /// Determines the unique 32-byte ID for the specified caption.
    function computeID32(string calldata caption) external pure returns (bytes32);

    /// Returns the consumer address where all price updates will be reported to.
    /// @dev If zero, new price updates will not be reported to any other external address.
    /// @dev The consumer contract must implement the `IWitPriceFeedsConsumer` interface, 
    /// @dev and accept this instance as source of truth.
    /// @dev It can only be settled by a curator on cloned instances.
    function consumer() external view returns (IWitPriceFeedsConsumer);

    /// Creates a Chainlink Aggregator proxy to the specified caption.
    /// @dev Reverts if caption is not supported.
    function createChainlinkAggregator(string calldata caption) external returns (address);

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint() external view returns (bytes4);

    /// @notice Returns last update price for the specified ID4 price feed.
    /// Note: This function is sanity-checked version of `getPriceUnsafe` which is useful in applications and
    /// smart contracts that require recentl updated price, and no hint of market deviation being currently excessive. 
    ///
    /// @dev Reverts if:
    /// - `PriceFeedNotFound()`: the price feed is not supported.
    /// - `StalePrice()`: the price feed has not been updated within the last `PriceUpdateConditions.heartbeatSecs`,
    ///
    /// @param id4 Unique ID4 identifier of a price feed supported by this contract.
    function getPrice(ID4 id4) external view returns (Price memory);
    
    /// @notice Returns last updated price if no older than `_age` seconds of the current time.
    /// Note: This function is a sanity-checked version of `getPriceUnsafe` which is useful in applications and
    /// smart contracts that require last known non-deviant price, last updated within specified time range.
    ///
    /// @dev Reverts if:
    /// - `PriceFeedNotFound()`: the price feed is not supported.
    /// - `StalePrice()`: the price feed has not been updated within the last `_age` seconds,
    /// 
    /// @param id4 Unique ID4 identifier of a price feed supported by this contract.
    /// @param age Maximum age of acceptable price value.
    function getPriceNotOlderThan(ID4 id4, uint24 age) external view returns (Price memory);

    /// @notice Returns last updated price without any sanity checks.
    /// Note: This function is unsafe as the returned price update may be arbitrarily far in the past.
    /// Users of this function should check the `timestamp` of each price feed to ensure that the returned values 
    /// are sufficiently recent for their application. If you need safe access to fresh data, please consider
    /// using calling to either `getPrice` or `getPriceNoOlderThan` variants.
    /// 
    /// @param id4 Unique ID4 identifier of a price feed supported by this contract.
    function getPriceUnsafe(ID4 id4) external view returns (Price memory);
    
    function lookupPriceFeed(ID4 id4) external view returns (PriceFeedInfo memory);
    function lookupPriceFeedCaption(ID4 id4) external view returns (string memory);
    function lookupPriceFeedExponent(ID4 id4) external view returns (int8);
    function lookupPriceFeedID32(ID4 id4) external view returns (bytes32);
    function lookupPriceFeedMapper(ID4 id4) external view returns (PriceFeedMapper memory);
    function lookupPriceFeedOracle(ID4 id4) external view returns (PriceFeedOracle memory);
    function lookupPriceFeedQualityMetrics(ID4 id4) external view returns (PriceFeedQoS memory);
    function lookupPriceFeedRadonBytecode(ID4 id4) external view returns (bytes memory);
    function lookupPriceFeedRadonHash(ID4 id4) external view returns (Witnet.RadonHash);
    
    /// @notice Returns last known price updates and deviations for all supported price feeds without any sanity checks.    
    function lookupPriceFeeds() external view returns (PriceFeedInfo[] memory);
    
    /// Tells whether there is a price feed settled with the specified caption.
    function supportsCaption(string calldata caption) external view returns (bool);

    /// The Wit/Oracle core address accepted as source of truth.
    function witOracle() external view returns (address);
}
