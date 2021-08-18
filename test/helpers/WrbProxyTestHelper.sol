// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../../contracts/impls/WitnetProxy.sol";

/**
 * @title Test Helper for the WitnetRequestBoardProxy contract
 * @dev The aim of this contract is:
 *  Raise the visibility modifier of WitnetRequestBoardProxy contract functions for testing purposes
 * @author Witnet Foundation
 */
contract WrbProxyTestHelper is WitnetProxy {

  constructor () {}
  function getWrbAddress() external view returns(address) {
    return implementation();
  }
  
  function upgradeWitnetRequestBoard(address _newWrb) external {
    address[] memory _reporters = new address[](1);
    _reporters[0] = msg.sender;
    upgradeTo(_newWrb, abi.encode(_reporters));
  }
}
