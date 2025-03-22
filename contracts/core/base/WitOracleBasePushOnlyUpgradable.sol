// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBasePushOnlyTrustless.sol";
import "../WitnetUpgradableBase.sol";
import "../../data/WitOracleDataLib.sol";

/// @title Push-only WitOracle "trustless" but yet "upgradable" base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBasePushOnlyUpgradable
    is 
        WitnetUpgradableBase,
        WitOracleBasePushOnlyTrustless
{
    constructor(bytes32 _versionTag, bool _upgradable)
        Ownable(msg.sender)
        WitnetUpgradableBase(_upgradable, _versionTag, "io.witnet.proxiable.board")
    {}


    // ================================================================================================================
    // ---Upgradeable -------------------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory _initData) virtual override internal {
        if (__proxiable().codehash == bytes32(0)) {
            // upon first initialization, store genesis beacon
            WitOracleTrustlessDataLib.data().beacons[
                Witnet.WIT_2_GENESIS_BEACON_INDEX
            ] = Witnet.Beacon({
                index: Witnet.WIT_2_GENESIS_BEACON_INDEX,
                prevIndex: Witnet.WIT_2_GENESIS_BEACON_PREV_INDEX,
                prevRoot: Witnet.WIT_2_GENESIS_BEACON_PREV_ROOT,
                ddrTalliesMerkleRoot: Witnet.WIT_2_GENESIS_BEACON_DDR_TALLIES_MERKLE_ROOT,
                droTalliesMerkleRoot: Witnet.WIT_2_GENESIS_BEACON_DRO_TALLIES_MERKLE_ROOT,
                nextCommitteeAggPubkey: [
                    Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_0,
                    Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_1,
                    Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_2,
                    Witnet.WIT_2_GENESIS_BEACON_NEXT_COMMITTEE_AGG_PUBKEY_3
                ]
            });
        } else {
            // otherwise, store beacon read from _initData, if any
            if (_initData.length > 0) {
                Witnet.Beacon memory _initBeacon = abi.decode(_initData, (Witnet.Beacon));
                WitOracleTrustlessDataLib.data().beacons[_initBeacon.index] = _initBeacon;
            }
        }
    }
}
