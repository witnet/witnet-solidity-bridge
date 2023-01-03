// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestMalleableBase.sol";

contract WitnetRequestRandomness
    is
        WitnetRequestMalleableBase
{
    bytes internal constant _WITNET_RANDOMNESS_BYTECODE_TEMPLATE = hex"0a0f120508021a01801a0210022202100b";

    constructor() {
        _initialize(hex"");
    }

    function _initialize(bytes memory)
        internal
        virtual override
    {
        super._initialize(_WITNET_RANDOMNESS_BYTECODE_TEMPLATE);
    }
}
