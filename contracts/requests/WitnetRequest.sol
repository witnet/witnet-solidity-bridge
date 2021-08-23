// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBase.sol";

contract WitnetRequest
    is
        WitnetRequestBase
{
    using Witnet for bytes;
    constructor(bytes memory _bytecode) {
        bytecode = _bytecode;
        hash = _bytecode.hash();
    }
}
