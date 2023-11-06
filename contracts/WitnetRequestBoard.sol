// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/V2/IWitnetRequestBoard.sol";
import "./interfaces/V2/IWitnetRequestFactory.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoard
    is
        IWitnetRequestBoard
{
    IWitnetRequestFactory immutable public override factory;

    constructor (IWitnetRequestFactory _factory) {
        require(
            _factory.class() == type(IWitnetRequestFactory).interfaceId,
            "WitnetRequestBoard: uncompliant factory"
        );
        factory = _factory;
    }
}