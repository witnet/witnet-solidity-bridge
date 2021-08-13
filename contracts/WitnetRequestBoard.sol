// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./interfaces/WitnetRequestBoardInterface.sol";

/// @title Witnet Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoard is
    WitnetRequestBoardInterface
{
    receive() external payable {
        revert("WitnetRequestBoard: no transfers accepted");
    }
}
