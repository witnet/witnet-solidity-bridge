// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetBytecodes.sol";
import "./WitnetRequestFactory.sol";

import "./interfaces/IWitnetRequestBoardEvents.sol";
import "./interfaces/IWitnetRequestBoardReporter.sol";
import "./interfaces/IWitnetRequestBoardRequestor.sol";
import "./interfaces/IWitnetRequestBoardView.sol";

import "./interfaces/IWitnetRequestBoardDeprecating.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoard is
    IWitnetRequestBoardDeprecating,
    IWitnetRequestBoardEvents,
    IWitnetRequestBoardReporter,
    IWitnetRequestBoardRequestor,
    IWitnetRequestBoardView
{
    WitnetRequestFactory immutable public factory;
    WitnetBytecodes immutable public registry;
    constructor (WitnetRequestFactory _factory) {
        require(
            _factory.class() == type(WitnetRequestFactory).interfaceId,
            "WitnetRequestBoard: uncompliant factory"
        );
        factory = _factory;
        registry = _factory.registry();
    }
}