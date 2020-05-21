// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "../../contracts/WitnetRequestsBoardProxy.sol";


/**
 * @title Test Helper for the WitnetRequestsBoardProxy contract
 * @dev The aim of this contract is:
 *  Raise the visibility modifier of WitnetRequestsBoardProxy contract functions for testing purposes
 * @author Witnet Foundation
 */
contract WrbProxyTestHelper is WitnetRequestsBoardProxy {

  constructor (address _witnetRequestsBoardAddress) public WitnetRequestsBoardProxy(_witnetRequestsBoardAddress) {}

  function checkLastId(uint256 _id) external returns(bool) {
    if (_id == currentLastId) {
      return true;
    } else {
      false;
    }
  }

  function getWrbAddress() external view returns(address) {
    return witnetRequestsBoardAddress;
  }

  function getControllerAddress(uint256 _id) external returns(address) {
    address wrb;
    uint256 offset;
    (wrb, offset) = getController(_id);
    return wrb;
  }

}
