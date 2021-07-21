// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../../contracts/utils/Upgradable.sol";

/**
 * @title Test Helper for mocking a WitnetRequestBoard Troy Horse implementation
 * @dev The aim of this contract is:
 *  Raise awareness of how important is to handle proper assertions when implementing 'initialize(bytes)'.
 * @author Witnet Foundation
 */
contract WitnetRequestBoardTroyHorse is Upgradable {

  constructor () {}

  function initialize(bytes calldata) external override {}

  function isUpgradableFrom(address) override external pure returns (bool) {
    return false;
  }

  function version() override external pure returns (string memory) {
    return "WitnetRequestBoard.TroyHorse";
  }
}
