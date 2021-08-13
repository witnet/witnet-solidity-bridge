// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetBoardUpgradableBase.sol";
import "../patterns/Destructible.sol";

/// @title Witnet Board base contract, with an Upgradable (and Destructible) touch.
/// @author The Witnet Foundation.
abstract contract WitnetBoardDestructibleBase
    is
        Destructible,
        WitnetBoardUpgradableBase
{
    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetBoardUpgradableBase(_upgradable, _versionTag)
    {}
}
