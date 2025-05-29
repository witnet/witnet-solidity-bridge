// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./WitPriceFeedsUpgradable.sol";

/// @title WitPriceFeedsUpgradableZkSync: On-demand Price Feeds registry for zkSync-ERA chains,
/// natively powered by the Wit/Oracle blockchain, but yet capable of aggregating 
/// price updates from other on-chain price-feed oracles too, if required.
/// 
/// Price feeds purely relying on the Wit/Oracle present multiple benefits:
/// - Anyone can permissionless pull and report price updates on-chain.
/// - Updating price feeds on-chain requires paying no extra "update fees".
/// - Prices can be extracted from independent and highly reputed exchanges and data providers.
/// - Actual data sources for each price feed can be introspected on-chain.
/// - Data source traceability is possible for every single price update.
///
/// Instances of this contract may also provide support for "routed price feeds" (computed as the 
/// product or mean average of up to other 8 different price feeds), as well as "cascade price feeds" 
/// (where multiple oracles could be used as backup when preferred ones don't manage to provide 
/// fresh enough updates for whatever reason).
///
/// Last but not least, this contract allows simple plug-and-play integration from 
/// smart contracts, dapps and DeFi projects currently adapted to operate with
/// other price feed solutions, like Chainlink, or Pyth. 
///
/// @author Guillermo Díaz <guillermo@witnet.io>

contract WitPriceFeedsUpgradableZkSync
    is
        WitPriceFeedsUpgradable
{
    function class() virtual override public pure returns (string memory) {
        return type(WitPriceFeedsUpgradableZkSync).name;
    }

    constructor(address _witOracle)
        WitPriceFeedsUpgradable(
            _witOracle, 
            bytes32("zksync-experimental"),
            true
        )
    {}

    /// ===============================================================================================================
    /// --- IWitPriceFeeds overrides ----------------------------------------------------------------------------------

    function createChainlinkAggregator(ID4 _id4)
        virtual override external
        returns (IWitPythChainlinkAggregator)
    {
        return IWitPythChainlinkAggregator(address(
            new WitPriceFeedsChainlinkAggregator(
                address(this), 
                ID4.unwrap(_id4)
            )
        ));
    }
}
