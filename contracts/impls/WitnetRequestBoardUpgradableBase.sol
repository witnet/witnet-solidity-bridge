// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBoardProxiableBase.sol";
import "../utils/Upgradable.sol";

/**
 * @title Witnet Board base contract, with an Upgradable (and Destructible) touch.
 * @author Witnet Foundation
 **/
abstract contract WitnetRequestBoardUpgradableBase
    is
        WitnetRequestBoardProxiableBase,        
        Upgradable
{
    bytes32 internal immutable __version;
    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        Upgradable(_upgradable)
    {
        __version = _versionTag;
    }

    /// @dev Retrieves human-readable version tag of current implementation.
    function version() public view override returns (bytes32) {
        return __version;
    }
}
