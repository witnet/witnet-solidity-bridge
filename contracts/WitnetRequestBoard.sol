// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetBytecodes.sol";
import "./WitnetRequestFactory.sol";
import "./interfaces/IWitnetRequestBoard.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoard
    is
        IWitnetRequestBoard
{
    function class() virtual external view returns (bytes4);
    function factory() virtual external view returns (WitnetRequestFactory);
    function registry() virtual external view returns (WitnetBytecodes);
}