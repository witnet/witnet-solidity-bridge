// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseUpgradable.sol";

/// @title Witnet Request Board "trustless" implementation contract for regular EVM-compatible chains.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustlessUpgradableDefault
    is 
        WitOracleBaseUpgradable
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleTrustlessUpgradableDefault).name;
    }

    constructor(
            EvmImmutables memory _immutables,
            uint256 _queryAwaitingBlocks,
            uint256 _queryReportingStake,
            WitOracleRadonRegistry _registry,
            bytes32 _versionTag,
            bool _upgradable
        )
        WitOracleBase(
            _immutables,
            _registry
        )
        WitOracleBaseTrustless(
            _queryAwaitingBlocks,
            _queryReportingStake
        )
        WitOracleBaseUpgradable(
            _versionTag,
            _upgradable
        )
    {}


    // ================================================================================================================
    // ---Upgradeable -------------------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory _initData) virtual override internal {
        if (__proxiable().codehash == bytes32(0)) {
            // upon first initialization, store genesis beacon
            WitOracleBlocksLib.data().beacons[
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
                WitOracleBlocksLib.data().beacons[_initBeacon.index] = _initBeacon;
            }
        }
    }
}
