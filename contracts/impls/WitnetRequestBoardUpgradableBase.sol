// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

/* solhint-disable var-name-mixedcase */

// Inherits from:
import "../WitnetRequestBoard.sol";
import "../patterns/Proxiable.sol";
import "../patterns/Upgradable.sol";

// Eventual deployment dependencies:
import "./WitnetProxy.sol";

/// @title Witnet Request Board base contract, with an Upgradable (and Destructible) touch.
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoardUpgradableBase
    is
        Proxiable,
        Upgradable,
        WitnetRequestBoard
{
    bytes32 internal immutable _VERSION;

    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        Upgradable(_upgradable)
    {
        _VERSION = _versionTag;
    }

    /// @dev Reverts if proxy delegatecalls to unexistent method.
    fallback() external payable {
        revert("WitnetRequestBoardUpgradableBase: not implemented");
    }

    // ================================================================================================================
    // --- Overrides 'Proxiable' --------------------------------------------------------------------------------------

    /// @dev Gets immutable "heritage blood line" (ie. genotype) as a Proxiable, and eventually Upgradable, contract.
    ///      If implemented as an Upgradable touch, upgrading this contract to another one with a different 
    ///      `proxiableUUID()` value should fail.
    function proxiableUUID() external pure override returns (bytes32) {
        return (
            /* keccak256("io.witnet.proxiable.board") */
            0x9969c6aff411c5e5f0807500693e8f819ce88529615cfa6cab569b24788a1018
        );
    }   

    // ================================================================================================================
    // --- Overrides 'Upgradable' --------------------------------------------------------------------------------------

    /// Retrieves human-readable version tag of current implementation.
    function version() public view override returns (bytes32) {
        return _VERSION;
    }

}
