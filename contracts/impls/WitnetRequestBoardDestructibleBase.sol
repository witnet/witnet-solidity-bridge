// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBoardUpgradableBase.sol";
import "../utils/Destructible.sol";

/**
 * @title Witnet Board base contract, with an Upgradable (and Destructible) touch.
 * @author Witnet Foundation
 **/
abstract contract WitnetRequestBoardDestructibleBase
    is
        WitnetRequestBoardUpgradableBase,
        Destructible
{
    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetRequestBoardUpgradableBase(_upgradable, _versionTag)
    {
    }
}
