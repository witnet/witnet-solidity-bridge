// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase
// solhint-disable payable-fallback

pragma solidity >=0.8.0 <0.9.0;

import "../patterns/Ownable2Step.sol";
import "../patterns/ReentrancyGuard.sol";
import "../patterns/Upgradeable.sol";

import "./WitnetProxy.sol";

/// @title Witnet Request Board base contract, with an Upgradeable (and Destructible) touch.
/// @author Guillermo Díaz <guillermo@otherplane.com>
abstract contract WitnetUpgradableBase
    is
        Ownable2Step,
        Upgradeable, 
        ReentrancyGuard
{
    bytes32 internal immutable _WITNET_UPGRADABLE_VERSION;

    address public immutable deployer = msg.sender;

    constructor(
            bool _upgradable,
            bytes32 _versionTag,
            string memory _proxiableUUID
        )
        Upgradeable(_upgradable)
    {
        _WITNET_UPGRADABLE_VERSION = _versionTag;
        proxiableUUID = keccak256(bytes(_proxiableUUID));
    }
    
    /// @dev Reverts if proxy delegatecalls to unexistent method.
    fallback() virtual external {
        revert("WitnetUpgradableBase: not implemented");
    }

   
    // ================================================================================================================
    // --- Overrides 'Proxiable' --------------------------------------------------------------------------------------

    /// @dev Gets immutable "heritage blood line" (ie. genotype) as a Proxiable, and eventually Upgradeable, contract.
    ///      If implemented as an Upgradeable touch, upgrading this contract to another one with a different 
    ///      `proxiableUUID()` value should fail.
    bytes32 public immutable override proxiableUUID;


    // ================================================================================================================
    // --- Overrides 'Upgradeable' --------------------------------------------------------------------------------------

    /// Retrieves human-readable version tag of current implementation.
    function version() public view virtual override returns (string memory) {
        return _toString(_WITNET_UPGRADABLE_VERSION);
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    /// Converts bytes32 into string.
    function _toString(bytes32 _bytes32)
        internal pure
        returns (string memory)
    {
        bytes memory _bytes = new bytes(_toStringLength(_bytes32));
        for (uint _i = 0; _i < _bytes.length;) {
            _bytes[_i] = _bytes32[_i];
            unchecked {
                _i ++;
            }
        }
        return string(_bytes);
    }

    // Calculate length of string-equivalent to given bytes32.
    function _toStringLength(bytes32 _bytes32)
        internal pure
        returns (uint _length)
    {
        for (; _length < 32; ) {
            if (_bytes32[_length] == 0) {
                break;
            }
            unchecked {
                _length ++;
            }
        }
    }

}