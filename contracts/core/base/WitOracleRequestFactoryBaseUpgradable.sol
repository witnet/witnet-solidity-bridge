// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "./WitOracleRequestFactoryBase.sol";
import "../WitnetUpgradableBase.sol";

/// @title Witnet Request Board EVM-default implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleRequestFactoryBaseUpgradable
    is 
        WitOracleRequestFactoryBase,
        WitnetUpgradableBase
{   
    modifier onlyDelegateCalls override(Clonable, Upgradeable) {
        _require(
            address(this) != _BASE,
            "not a delegate call"
        ); _;
    }

    modifier notOnFactory virtual override {
        _require(
            address(this) != __proxy()
                && address(this) != base(),
            "not on factory"
        ); _;
    }

    modifier onlyOnFactory virtual override {
        _require(
            address(this) == __proxy()
                || address(this) == base(),
            "not the factory"
        ); _;
    }

    constructor(
            bytes32 _versionTag,
            bool _upgradable
        )
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.requests.factory"
        )
    {
        // let logic contract be used as a factory, while avoiding further initializations:
        __proxiable().proxy = address(this);
        __proxiable().implementation = address(this);
        __witOracleRequestFactory().owner = address(0);
    }

    function version()
        virtual override(WitOracleRequestFactoryBase, WitnetUpgradableBase)
        public view
        returns (string memory)
    {
        return WitnetUpgradableBase.version();
    }
    

    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory) virtual override internal {
        if (__proxiable().codehash == bytes32(0)) {
            __proxiable().proxy = address(this);
        }
        __proxiable().implementation = base();
    }


    // ================================================================================================================
    // --- Overrides 'Ownable2Step' -----------------------------------------------------------------------------------

    /// @notice Returns the address of the pending owner.
    function pendingOwner()
        public view
        virtual override
        returns (address)
    {
        return __witOracleRequestFactory().pendingOwner;
    }

    /// @notice Returns the address of the current owner.
    function owner()
        virtual override
        public view
        returns (address)
    {
        return __witOracleRequestFactory().owner;
    }

    /// @notice Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        virtual override public
        onlyOwner
    {
        __witOracleRequestFactory().pendingOwner = _newOwner;
        emit OwnershipTransferStarted(owner(), _newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`_newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    function _transferOwnership(address _newOwner)
        internal
        virtual override
    {
        delete __witOracleRequestFactory().pendingOwner;
        address _oldOwner = owner();
        if (_newOwner != _oldOwner) {
            __witOracleRequestFactory().owner = _newOwner;
            emit OwnershipTransferred(_oldOwner, _newOwner);
        }
    }

    // ================================================================================================================
    /// --- Overrides Clonable ----------------------------------------------------------------------------------------

    /// @notice Tells whether a WitOracleRequest or a WitOracleRequestTemplate has been properly initialized.
    function initialized() virtual override public view returns (bool) {
        return (
            super.initialized()
                || __implementation() == base()
        );
    }

    /// @notice Contract address to which clones will be re-directed.
    function self()
        virtual override
        public view
        returns (address)
    {
        return (__proxy() != address(0)
            ? __implementation()
            : base()
        );
    }

    function _determineWitOracleRequestAddressAndSalt(Witnet.RadonHash _radHash)
        virtual override internal view
        returns (address, bytes32)
    {
        bytes32 _salt = keccak256(
            abi.encodePacked(
                Witnet.RadonHash.unwrap(_radHash), 
                bytes4(_WITNET_UPGRADABLE_VERSION)
            )
        );
        return (
            address(uint160(uint256(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    _salt,
                    keccak256(_cloneBytecode())
                )
            )))), _salt
        );
    }

    function _determineWitOracleRequestTemplateAddressAndSalt(
            bytes32[] memory _retrieveHashes,
            bytes16 _aggregateReducerHash,
            bytes16 _tallyReducerHash
        )
        virtual override internal view
        returns (address, bytes32)
    {
        bytes32 _salt = keccak256(
            // As to avoid template address collisions from:
            abi.encodePacked( 
                // - different factory major or mid versions:
                bytes4(_WITNET_UPGRADABLE_VERSION),
                // - different templates params:
                _retrieveHashes,
                _aggregateReducerHash,
                _tallyReducerHash
            )
        );
        return (
            address(uint160(uint256(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    _salt,
                    keccak256(_cloneBytecode())
                )
            )))), _salt
        );
    }
}
