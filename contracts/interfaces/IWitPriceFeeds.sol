// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPriceFeedsMappingSolver.sol";
import "./legacy/IWitPyth.sol";
import "./legacy/IWitPythChainlinkAggregator.sol";

interface IWitPriceFeeds {

    type ID4 is bytes4;

    enum Mappers {
        None,
        Fallback,
        Hottest,
        Product,
        Inverse
    }

    enum Oracles {
        Witnet,
        ERC2362,
        Chainlink,
        Pyth
    }

    event PriceFeedUpdate(
        ID4 indexed ID4,
        Witnet.Timestamp timestamp, 
        Witnet.TransactionHash trail,
        uint64 price,
        int56 deltaPrice,
        int8 exponent
    );

    struct Price {
        int8 exponent;
        uint64 price;
        int56  deltaPrice;
        Witnet.Timestamp timestamp;
        Witnet.TransactionHash trail;
    }

    struct Info {
        IWitPyth.ID id;
        int8 exponent;
        string symbol;
        Mapper mapper;
        Oracle oracle;
        UpdateConditions updateConditions;
        Price lastUpdate;
    }

    struct Mapper {
        Mappers class;
        string[] deps;
    }

    struct Oracle {
        Oracles class;
        address target;
        bytes32 sources;
    }

    struct UpdateConditions {
        uint24 callbackGas;
        bool   computeEma;
        uint24 cooldownSecs;
        uint24 heartbeatSecs;
        uint16 maxDeviation1000;
        uint16 minWitnesses;
    }

    /// Creates a light-proxy clone to the `target()` contract address, to be owned by the specified `curator` address. 
    /// Operators of cloned contracts can optionally settle one single `IWitPriceFeedConsumer` consuming contract. 
    /// The consuming contract, if settled, will be immediately reported upon every verified price update pushed 
    /// into `WitPriceFeeds`. Either way, price feeds data will be stored in the `WitPriceFeeds` storage. 
    /// @dev Reverts if the salt has already been used, or trying to inherit mapped price feeds.
    /// @param curator Address that will have rights to manage price feeds on the new light-proxy clone.
    function clone(address curator) external returns (address);

    /// Returns the consumer address where all price updates will be reported to.
    /// @dev If zero, price updates will not be reported to any other external address.
    /// @dev It can only be settled or an curator on a customized instance.
    function consumer() external view returns (address);

    /// Default update conditions that apply to brand new price feeds.
    function defaultUpdateConditions() external view returns (IWitPriceFeeds.UpdateConditions calldata);

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint() external view returns (bytes4);

    /// Determines unique ID for the specified symbol.
    function hash(string calldata symbol) external pure returns (IWitPyth.ID);

    /// @notice Master address from which this contract was cloned.
    function master() external view returns (address);

    /// @notice Contract address to which clones will be re-directed.
    function target() external view returns (address);

    /// @notice Returns last update price for the specified ID4 price feed.
    /// Note: This function is sanity-checked version of `getPriceUnsafe` which is useful in applications and
    /// smart contracts that require recentl updated price, and no hint of market deviation being currently excessive. 
    ///
    /// @dev Reverts if:
    /// - `StalePrice()`: the price feed has not been updated within the last `UpdateConditions.heartbeatSecs`,
    /// - `DeviantPrice()`: a deviation greater than `UpdateConditions.maxDeviation1000` was detected upon last update attempt.
    /// - `InvalidGovernanceTarget()`: no EMA is curretly settled to be computed for this price feed.
    ///
    /// @param id4 Unique ID4 identifier of a price feed supported by this contract.
    function getPrice(ID4 id4) external view returns (Price memory);
    
    /// @notice Returns last updated price if no older than `_age` seconds of the current time.
    /// Note: This function is a sanity-checked version of `getPriceUnsafe` which is useful in applications and
    /// smart contracts that require last known non-deviant price, last updated within specified time range.
    ///
    /// @dev Reverts if:
    /// - `StalePrice()`: the price feed has not been updated within the last `_age` seconds,
    /// - `InvalidGovernanceTarget()`: no EMA is settled to be computed for specified price feed.
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
    /// @dev Reverts if:
    /// - `InvalidGovernanceTarget()`: no EMA is settled to be computed for specified price feed.
    /// 
    /// @param id4 Unique ID4 identifier of a price feed supported by this contract.
    function getPriceUnsafe(ID4 id4) external view returns (Price memory);
    
    function lookupPriceFeed(ID4 id4) external view returns (Info memory);
    function lookupPriceFeedCaption(ID4 id4) external view returns (string memory);
    function lookupPriceFeedExponent(ID4 id4) external view returns (int8);
    function lookupPriceFeedID(ID4 id4) external view returns (bytes32);

    /// @notice Returns last known price updates and deviations for all supported price feeds without any sanity checks.    
    function lookupPriceFeeds() external view returns (Info[] memory);
    
    /// Tells whether there is a price feed settled with the specified caption.
    function supportsCaption(string calldata caption) external view returns (bool);

    /// Creates a Chainlink Aggregator proxy to the specified symbol.
    /// @dev Reverts if symbol is not supported.
    function createChainlinkAggregator(string calldata symbol) external returns (IWitPythChainlinkAggregator);}
