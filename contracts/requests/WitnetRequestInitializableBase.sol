// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBase.sol";
import "../patterns/Initializable.sol";

abstract contract WitnetRequestInitializableBase
    is
        Initializable,
        WitnetRequestBase
{
    using Witnet for bytes;
    function initialize(bytes memory _bytecode)
        public
        virtual override
    {
        require(
            bytecode.length == 0,
            "WitnetRequestInitializableBase: cannot change bytecode"
        );
        bytecode = _bytecode;
        hash = _bytecode.hash();
    }
}
