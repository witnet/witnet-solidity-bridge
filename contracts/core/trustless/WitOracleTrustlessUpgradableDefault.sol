// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleTrustlessDefault.sol";
import "../WitnetUpgradableBase.sol";

/// @title Witnet Request Board "trustless" implementation contract for regular EVM-compatible chains.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustlessUpgradableDefault
    is 
        WitOracleTrustlessDefault,
        WitnetUpgradableBase
{
    function class()
        virtual override(WitOracleTrustlessDefault, WitnetUpgradableBase) 
        public view 
        returns (string memory)
    {
        return type(WitOracleTrustlessUpgradableDefault).name;
    }

    constructor(
            WitOracleRadonRegistry _registry,
            WitOracleRequestFactory _factory,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas,
            uint256 _queryAwaitingBlocks,
            uint256 _queryReportingStake
        )
        Ownable(msg.sender)
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.board"
        )
        WitOracleTrustlessDefault(
            _registry,
            _factory,
            _reportResultGasBase,
            _reportResultWithCallbackGasBase,
            _reportResultWithCallbackRevertGasBase,
            _sstoreFromZeroGas,
            _queryAwaitingBlocks,
            _queryReportingStake
        )
    {}

    
    // ================================================================================================================
    // ---Upgradeable -------------------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData) virtual override public {
        address _owner = owner();

        if (_owner == address(0)) {
            // initializing for the first time...

            // transfer ownership to first initializer
            _transferOwnership(_owner);

            // save into storage genesis beacon
            __storage().beacons[
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
            // only owner can initialize a new upgrade:
            _require(
                msg.sender == _owner,
                "not the owner"
            );
        }

        if (
            __proxiable().codehash != bytes32(0)
                && __proxiable().codehash == codehash()
        ) {
            _revert("already upgraded");
        }
        __proxiable().codehash = codehash();

        _require(address(registry).code.length > 0, "inexistent registry");
        _require(registry.specs() == type(WitOracleRadonRegistry).interfaceId, "uncompliant registry");
        
        // Settle given beacon, if any:
        if (_initData.length > 0) {
            Witnet.Beacon memory _beacon = abi.decode(_initData, (Witnet.Beacon));
            __storage().beacons[_beacon.index] = _beacon;
        }

        emit Upgraded(_owner, base(), codehash(), version());
    }


    /// ================================================================================================================
    /// --- Internal methods -------------------------------------------------------------------------------------------

    function _require(bool _condition, string memory _reason)
        virtual override (WitOracleTrustlessBase, WitnetUpgradableBase)
        internal view 
    {
        WitOracleTrustlessBase._require(_condition, _reason);
    }

    function _revert(string memory _reason)
        virtual override (WitOracleTrustlessBase, WitnetUpgradableBase)
        internal view
    {
        WitOracleTrustlessBase._revert(_reason);
    }
}
