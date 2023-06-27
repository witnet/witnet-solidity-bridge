// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "../WitnetUpgradableBase.sol";
import "../../WitnetBlocks.sol";
import "../../data/WitnetBlocksData.sol";

/// @title WitnetBlocks decentralized block relaying contract
/// @author The Witnet Foundation
contract WitnetBlocksDefault
    is 
        WitnetBlocks,
        WitnetBlocksData,
        WitnetUpgradableBase
{
    using WitnetV2 for WitnetV2.Beacon;

    IWitnetRequestBoardV2 immutable public override board;
    uint256 immutable internal __genesisIndex;
    
    uint256 immutable public override ROLLUP_DEFAULT_PENALTY_WEI;
    uint256 immutable public override ROLLUP_MAX_GAS;

    constructor(
            address _counterFactualAddress,
            WitnetV2.Beacon memory _genesis,
            uint256 _rollupDefaultPenaltyWei,
            uint256 _rollupMaxGas,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.blocks"
        )
    {
        assert(_counterFactualAddress != address(0));
        assert(_rollupDefaultPenaltyWei > 0);
        assert(_rollupMaxGas > 0);
        board = IWitnetRequestBoardV2(_counterFactualAddress);
        __genesisIndex = _genesis.index;
        __blocks().beacons[__genesisIndex] = _genesis;
        __blocks().lastBeaconIndex = _genesis.index;
        ROLLUP_DEFAULT_PENALTY_WEI = _rollupDefaultPenaltyWei;
        ROLLUP_MAX_GAS = _rollupMaxGas;        
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory initdata) 
        override public
        onlyDelegateCalls // => we don't want the logic base contract to be ever initialized
    {
        if (
            __proxiable().proxy == address(0)
                && __proxiable().implementation == address(0)
        ) {
            // a proxy is being initialized for the first time...
            __proxiable().proxy = address(this);
            _transferOwnership(msg.sender);
        } else {
            // only the owner can initialize:
            if (msg.sender != owner()) {
                revert("WitnetBlocksDefault: not the owner");
            }
        }
        require(
            __proxiable().implementation != base(),
            "WitnetBlocksDefault: already initialized"
        );
        if (initdata.length > 0) {
            WitnetV2.Beacon memory _checkpoint = abi.decode(initdata, (WitnetV2.Beacon));
            uint256 _lastBeaconIndex = __blocks().lastBeaconIndex;
            uint256 _nextBeaconIndex = __blocks().nextBeaconIndex;
            require(
                _checkpoint.index > _lastBeaconIndex,
                "WitnetBlocksDefault: cannot rollback"
            );
            require(
                _nextBeaconIndex == 0 || _checkpoint.index < _nextBeaconIndex,
                "WitnetBlocksDefault: pending rollups"
            );
            __blocks().lastBeaconIndex = _checkpoint.index;
            __blocks().beacons[_checkpoint.index] = _checkpoint;
            emit FastForward(msg.sender, _checkpoint.index, _lastBeaconIndex);
        }
        __proxiable().implementation = base();
        emit Upgraded(msg.sender, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _from == owner()
        );
    }


    // ================================================================================================================
    // --- Implementation of 'IWitnetBlocks' --------------------------------------------------------------------------

    function class() virtual override(WitnetUpgradableBase, IWitnetBlocks) external pure returns (bytes4) {
        return type(IWitnetBlocks).interfaceId;
    }
    
    function genesis()
        virtual override
        external view
        returns (WitnetV2.Beacon memory)
    {
        return __blocks().beacons[__genesisIndex];
    }

    function getBeaconDisputedQueries(uint256 beaconIndex)
        virtual override
        external view
        returns (bytes32[] memory)
    {
        return __tracks_(beaconIndex).queries;
    }

    function getCurrentBeaconIndex()
        virtual override
        public view
        returns (uint256)
    {
        // solhint-disable not-rely-on-time
        return WitnetV2.beaconIndexFromTimestamp(block.timestamp);
    }

    function getCurrentEpoch()
        virtual override
        public view
        returns (uint256)
    {
        // solhint-disable not-rely-on-time
        return WitnetV2.epochFromTimestamp(block.timestamp);
    }
    
    function getLastBeacon()
        virtual override
        external view
        returns (WitnetV2.Beacon memory _beacon)
    {
        return __blocks().beacons[__blocks().lastBeaconIndex];
    }

    function getLastBeaconEpoch()
        virtual override
        external view
        returns (uint256)
    {
        return getLastBeaconIndex() * 10;
    }

    function getLastBeaconIndex()
        virtual override
        public view 
        returns (uint256)
    {
        return __blocks().lastBeaconIndex;
    }

    function getNextBeaconIndex()
        virtual override
        external view 
        returns (uint256)
    {
        return __blocks().nextBeaconIndex;
    }

    function __insertBeaconSuccessor(uint nextBeaconIndex, uint tallyBeaconIndex)
        virtual internal
        returns (uint256)
    {
        uint _currentSuccessor = __blocks().beaconSuccessorOf[nextBeaconIndex];
        if (_currentSuccessor == 0) {
            __blocks().beaconSuccessorOf[nextBeaconIndex] = tallyBeaconIndex;
            return tallyBeaconIndex;
        } else if (_currentSuccessor >= tallyBeaconIndex) {
            __blocks().beaconSuccessorOf[tallyBeaconIndex] = _currentSuccessor;
            return tallyBeaconIndex;
        } else {
            return __insertBeaconSuccessor(_currentSuccessor, tallyBeaconIndex);
        }
    }

    function disputeQuery(bytes32 queryHash, uint256 tallyBeaconIndex)
        virtual override
        external 
    {
        require(
            msg.sender == address(board), 
            "WitnetBlocksDefault: unauthorized"
        );
        if (tallyBeaconIndex > __blocks().lastBeaconIndex) {
            if (__blocks().nextBeaconIndex > __blocks().lastBeaconIndex) {
                // pending rollup
                if (tallyBeaconIndex < __blocks().nextBeaconIndex) {
                    __blocks().beaconSuccessorOf[tallyBeaconIndex] = __blocks().nextBeaconIndex;
                    __blocks().nextBeaconIndex = tallyBeaconIndex;
                } else if (tallyBeaconIndex > __blocks().nextBeaconIndex) {
                    __blocks().nextBeaconIndex = __insertBeaconSuccessor(__blocks().nextBeaconIndex, tallyBeaconIndex);
                    if (tallyBeaconIndex > __blocks().latestBeaconIndex) {
                        __blocks().latestBeaconIndex = tallyBeaconIndex;
                    }
                }
            } else {
                // settle next rollup
                __blocks().nextBeaconIndex = tallyBeaconIndex;
                __blocks().latestBeaconIndex = tallyBeaconIndex;
            }
            BeaconTracks storage __tracks = __tracks_(tallyBeaconIndex);
            if (!__tracks.disputed[queryHash]) {
                __tracks.disputed[queryHash] = true;
                __tracks.queries.push(queryHash);
            }
        } else {
            revert("WitnetBlocksDefault: too late dispute");
        }
    }

    function rollupTallyHashes(
            WitnetV2.FastForward[] calldata ffs,
            bytes32[] calldata tallyHashes,
            uint256 tallyOffset,
            uint256 tallyLength
        )
        external 
        // TODO: modifiers
        returns (uint256 weiReward)
    {
        uint _nextBeaconIndex = __blocks().nextBeaconIndex;
        uint _lastBeaconIndex = __blocks().lastBeaconIndex;
        require(
            ffs.length >= 1
                && ffs[ffs.length - 1].next.index <= _nextBeaconIndex,
            "WitnetBlocksDefault: misleading rollup"
        );
        if (_nextBeaconIndex > _lastBeaconIndex) {
            WitnetV2.Beacon memory _lastBeacon = __blocks().beacons[_lastBeaconIndex];
            for (uint _ix = 0; _ix < ffs.length; _ix ++) {
                _lastBeacon = _lastBeacon.verifyFastForward(ffs[_ix ++]);
            }
            emit FastForward(
                msg.sender, 
                _lastBeacon.index, 
                _lastBeaconIndex
            );
            {
                __blocks().beaconSuccessorOf[_lastBeaconIndex] = _lastBeacon.index;
                _lastBeaconIndex = _lastBeacon.index;
                __blocks().lastBeaconIndex = _lastBeaconIndex;
                __blocks().beacons[_lastBeaconIndex] = _lastBeacon;
            }
        }
        if (_nextBeaconIndex == _lastBeaconIndex) {
            BeaconTracks storage __tracks = __tracks_(_nextBeaconIndex);
            require(
                tallyOffset == __tracks.offset
                    && tallyOffset + tallyLength == tallyHashes.length,
                "WitnetBlocksDefault: out of range"
            );
            require(
                WitnetV2.merkle(tallyHashes) == __blocks().beacons[_nextBeaconIndex].ddrTallyRoot,
                "WitnetBlocksDefault: invalid tallies"
            );
            uint _maxTallyOffset = tallyOffset + tallyLength;
            for (; tallyOffset < _maxTallyOffset; tallyOffset ++) {
                (bytes32 _queryHash, uint256 _queryStakes) = board.determineQueryTallyHash(tallyHashes[tallyOffset]);
                require(
                    __tracks.disputed[_queryHash],
                    "WitnetBlocksDefault: already judged"
                );
                __tracks.disputed[_queryHash] = false;
                weiReward += _queryStakes;
            }
            if (tallyOffset == tallyHashes.length) {
                __blocks().nextBeaconIndex = __blocks().beaconSuccessorOf[_nextBeaconIndex];
            } else {
                __tracks.offset = tallyOffset;
            }
            emit Rollup(msg.sender, _nextBeaconIndex, tallyOffset, weiReward);
        } else {
            revert("WitnetBlocksDefault: no pending rollup");
        }
    }
}
