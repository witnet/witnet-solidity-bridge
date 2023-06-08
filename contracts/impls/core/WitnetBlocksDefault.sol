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
    IWitnetRequestBoardV2 override immutable public board;
    
    uint256 immutable internal __genesis_index;
    bytes32 immutable internal __genesis_root;

    constructor(
            uint256 _genesisIndex,
            bytes32 _genesisRoot,
            address _counterFactualAddress,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.blocks"
        )
    {
        board = IWitnetRequestBoardV2(_counterFactualAddress);
        __blocks().lastBeacon = WitnetV2.Beacon({
            index: _genesisIndex,
            root: _genesisRoot
        });
        __genesis_index = _genesisIndex;
        __genesis_root = _genesisRoot; 
    }
    
    function class() virtual override(WitnetUpgradableBase, IWitnetBlocks) external pure returns (bytes4) {
        return type(IWitnetBlocks).interfaceId;
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
            "WitnetBlocks: already initialized"
        );
        if (initdata.length > 0) {
            WitnetV2.Beacon memory _checkpoint = abi.decode(initdata, (WitnetV2.Beacon));
            uint256 _lastBeaconIndex = __blocks().lastBeacon.index;
            require(
                _checkpoint.index > _lastBeaconIndex,
                "WitnetBlocksDefault: illegal rollback"
            );
            __blocks().lastBeacon = _checkpoint;
            emit Rollup(msg.sender, _checkpoint.index, _lastBeaconIndex);
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

    function genesis()
        virtual override
        external view
        returns (WitnetV2.Beacon memory)
    {
        return WitnetV2.Beacon({
            index: __genesis_index,
            root: __genesis_root
        });
    }
    
    function getLastBeacon()
        virtual override
        external view
        returns (WitnetV2.Beacon memory _beacon)
    {
        return __blocks().lastBeacon;
    }

    function getLastBeaconIndex()
        virtual override
        external view 
        returns (uint256)
    {
        return __blocks().lastBeacon.index;
    }

    function getCurrentBeaconIndex()
        virtual override
        public view
        returns (uint256)
    {
        // solhint-disable not-rely-on-time
        return WitnetV2.beaconIndexFromTimestamp(block.timestamp);
    }

    function getNextBeaconIndex()
        virtual override
        external view
        returns (uint256) 
    {
        return getCurrentBeaconIndex() + 1;
    }
}