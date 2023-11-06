// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../IWitnetRequestBoardDeprecating.sol";
import "../IWitnetRequestBoardEvents.sol";
import "../IWitnetRequestBoardReporter.sol";
import "../IWitnetRequestBoardRequestor.sol";
import "../IWitnetRequestBoardView.sol";

import "./IWitnetRequestFactory.sol";

abstract contract IWitnetRequestBoard
    is
        IWitnetRequestBoardDeprecating,
        IWitnetRequestBoardEvents,
        IWitnetRequestBoardReporter,
        IWitnetRequestBoardRequestor,
        IWitnetRequestBoardView
{
    function class() virtual external view returns (bytes4);
    function factory() virtual external view returns (IWitnetRequestFactory);
    function registry() virtual external view returns (IWitnetBytecodes);
}
