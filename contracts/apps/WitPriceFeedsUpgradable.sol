// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../core/WitnetUpgradableBase.sol";
import "./WitPriceFeedsV21.sol";

/// @title WitPriceFeedsUpgradable: Upgradable on-demand Price Feeds registry for EVM-compatible 
/// L1/L2 chains, natively powered by the Wit/Oracle blockchain, but yet capable of aggregating 
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

contract WitPriceFeedsUpgradable
    is
        WitPriceFeedsV21,
        WitnetUpgradableBase
{
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.RadonHash;
    using Witnet for Witnet.Timestamp;

    using WitPriceFeedsDataLib for ID4;
    using WitPriceFeedsDataLib for UpdateConditions;

    function class() virtual override public pure returns (string memory) {
        return type(WitPriceFeedsUpgradable).name;
    }

    constructor(
            address _witOracle, 
            address _witOracleRadonRegistry,
            bytes32 _versionTag,
            bool    _upgradable
        )
        WitPriceFeedsV21(
            _witOracle, 
            _witOracleRadonRegistry, 
            msg.sender
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.feeds.price"
        )
    {}


    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory _initData) virtual override internal {
        if (__proxiable().codehash == bytes32(0)) {
            __storage().requiredWitParams = IWitPriceFeedsAdmin.WitParams({
                minWitCommitteeSize: 3,
                maxWitCommitteeSize: 0
            });
        
        } else {
            // otherwise, store beacon read from _initData, if any
            if (_initData.length > 0) {
                __storage().requiredWitParams = abi.decode(_initData, (IWitPriceFeedsAdmin.WitParams));
            }
        }
    }


    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = owner();
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }
}
