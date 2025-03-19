// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPriceFeedsMappingSolver.sol";
import "./legacy/IWitPyth.sol";
import "./legacy/IWitPythChainlinkAggregator.sol";

interface IWitPriceFeeds is IWitPyth {

    type ID4 is bytes4;

    struct Info {
        ID id;
        int8 exponent;
        Witnet.RadonHash radonHash;
        string symbol;
    }

    struct UpdateConditions {
        bool   computeEma;
        uint24 cooldownSecs;
        uint24 heartbeatSecs;
        uint16 maxDeviation1000;
    }

    function fetchChainlinkAggregator(ID4 id4) external returns (IWitPythChainlinkAggregator);

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint() external view returns (bytes4);

    /// Determines unique ID for specified `symbol` string.
    function hash(string calldata symbol) external pure returns (ID);

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
    /// @param ema Whether to fetch the computed exponential moving average, or the price just as reported from the Wit/Oracle..
    function getPrice(ID4 id4, bool ema) external view returns (Price memory);
    
    /// @notice Returns last updated price if no older than `_age` seconds of the current time.
    /// Note: This function is a sanity-checked version of `getPriceUnsafe` which is useful in applications and
    /// smart contracts that require last known non-deviant price, last updated within specified time range.
    ///
    /// @dev Reverts if:
    /// - `StalePrice()`: the price feed has not been updated within the last `_age` seconds,
    /// - `InvalidGovernanceTarget()`: no EMA is settled to be computed for specified price feed.
    /// 
    /// @param id4 Unique ID4 identifier of a price feed supported by this contract.
    /// @param ema Whether to fetch the computed exponential moving average, or the price as reported from the Wit/Oracle.
    /// @param age Maximum age of acceptable price value.
    function getPriceNotOlderThan(ID4 id4, bool ema, uint24 age) external view returns (Price memory);

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
    /// @param ema Whether to fetch the computed exponential moving average, or the price as reported from the Wit/Oracle.
    function getPriceUnsafe(ID4 id4, bool ema) external view returns (Price memory);
    
    /// @notice Returns last known price updates and deviations for all supported price feeds without any sanity checks.
    function getPricesUnsafe() external view returns (Price[] memory);
        
    function lookupPriceFeed(ID4 id4) external view returns (Info memory);
    function lookupPriceFeedSolver(ID4 id4) external view returns (IWitPriceFeedsMappingSolver, ID4[] memory);
    function lookupPriceFeedUpdateConditions(ID4 id4) external view returns (UpdateConditions memory);
    function lookupSymbol(ID4 id4) external view returns (string memory);

    function supportedPriceFeeds() external view returns (Info[] memory);
    function supportsPriceFeed(string calldata symbol) external view returns (bool);

    function witOracleRequiredCommitteeSizeRange() external view returns (uint16, uint16);
}
