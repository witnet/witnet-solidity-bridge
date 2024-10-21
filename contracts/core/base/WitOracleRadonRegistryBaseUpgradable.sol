// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "../WitnetUpgradableBase.sol";
import "../base/WitOracleRadonRegistryBase.sol";

/// @title Witnet Request Board EVM-default implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleRadonRegistryBaseUpgradable
    is 
        WitOracleRadonRegistryBase,
        WitnetUpgradableBase
{    
    constructor(
            bytes32 _versionTag,
            bool _upgradable
        )
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.bytecodes"
        )
    {}
    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData) 
        public
        override
    {
        address _owner = __bytecodes().owner;
        if (_owner == address(0)) {
            // set owner from  the one specified in _initData
            _owner = abi.decode(_initData, (address));
            __bytecodes().owner = _owner;
        } else {
            // only owner can initialize:
            if (msg.sender != _owner) {
                _revert("not the owner");
            }
        }

        if (__bytecodes().base != address(0)) {
            // current implementation cannot be initialized more than once:
            if(__bytecodes().base == base()) {
                _revert("already initialized");
            }
        }        
        __bytecodes().base = base();

        emit Upgraded(_owner, base(), codehash(), version());
    }

    // ================================================================================================================
    // --- Overrides 'Ownable2Step' -----------------------------------------------------------------------------------

    /// Returns the address of the pending owner.
    function pendingOwner()
        public view
        virtual override
        returns (address)
    {
        return __bytecodes().pendingOwner;
    }

    /// Returns the address of the current owner.
    function owner()
        public view
        virtual override
        returns (address)
    {
        return __bytecodes().owner;
    }

    /// Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        public
        virtual override
        onlyOwner
    {
        __bytecodes().pendingOwner = _newOwner;
        emit OwnershipTransferStarted(owner(), _newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`_newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    function _transferOwnership(address _newOwner)
        internal
        virtual override
    {
        delete __bytecodes().pendingOwner;
        address _oldOwner = owner();
        if (_newOwner != _oldOwner) {
            __bytecodes().owner = _newOwner;
            emit OwnershipTransferred(_oldOwner, _newOwner);
        }
    }
}
