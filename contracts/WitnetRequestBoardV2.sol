// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetBlocks.sol";
import "./WitnetBytecodes.sol";
import "./WitnetRequestFactory.sol";

/// @title Witnet Request Board V2 functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoardV2
    is
        IWitnetRequestBoardV2
{
    WitnetBlocks immutable public blocks;
    WitnetRequestFactory immutable public factory;
    WitnetBytecodes immutable public registry;
    constructor (
            WitnetBlocks _blocks,
            WitnetRequestFactory _factory
        )
    {
        require(
            _blocks.class() == type(WitnetBlocks).interfaceId,
            "WitnetRequestBoardV2: uncompliant blocks"
        );
        require(
            _factory.class() == type(WitnetRequestFactory).interfaceId,
            "WitnetRequestBoardV2: uncompliant factory"
        );
        blocks = _blocks;
        factory = _factory;
        registry = _factory.registry();
    }
}