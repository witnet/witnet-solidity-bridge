// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma abicoder v2;

import "./impls/trustable/WitnetRequestBoardV03.sol";

contract WitnetRequestBoard is WitnetRequestBoardV03 {
    constructor(bool _upgradable, bytes32 _versionTag)
        WitnetRequestBoardV03(_upgradable, _versionTag)
    {}
}
