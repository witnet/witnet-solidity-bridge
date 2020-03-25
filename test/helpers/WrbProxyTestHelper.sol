pragma solidity 0.6.4;

import "../../contracts/WitnetRequestsBoardProxy.sol";


/**
 * @title Test Helper for the WitnetRequestsBoardProxy contract
 * @dev The aim of this contract is:
 *  Raise the visibility modifier of WitnetRequestsBoardProxy contract functions for testing purposes
 * @author Witnet Foundation
 */
contract WrbProxyTestHelper is WitnetRequestsBoardProxy {

  constructor (address _witnetRequestsBoardAddress) WitnetRequestsBoardProxy(_witnetRequestsBoardAddress) public {}

  function checkLastId(uint256 _id) public returns(bool) {
    if (_id == currentLastId) {
      return true;
    } else {
      false;
    }
  }

  function getWrbAddress() public view returns(address) {
    return witnetRequestsBoardAddress;
  }

  function getControllerAddress(uint256 _id) public returns(address) {
    address wrb;
    uint256 offset;
    (wrb, offset) = getController(_id);
    return wrb;
  }

}
