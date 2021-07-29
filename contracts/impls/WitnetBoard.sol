// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/WitnetRequestBoardInterface.sol";

/**
 * @title Witnet Board functionality base contract.
 * @author Witnet Foundation
 **/
abstract contract WitnetBoard is
    WitnetRequestBoardInterface
{
    receive() external payable {
        revert("WitnetProxiableBoard: no ETH accepted");
    }
    fallback() external payable {
        revert("WitnetProxiableBoard: not implemented");
    }
}
