pragma solidity ^0.5.0;

import "../../contracts/WitnetRequestsBoardProxy.sol";


/**
 * @title Test Helper for the WitnetRequestsBoardProxy contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of WitnetRequestsBoardProxy contract functions for testing purposes
 * @author Witnet Foundation
 */
contract WrbProxyTestHelper is WitnetRequestsBoardProxy {

  constructor (address _witnetRequestsBoardAddress) WitnetRequestsBoardProxy(_witnetRequestsBoardAddress) public {}

  function getLastId() public returns(uint256) {
    // uint256 n = lastIdsControllers.length;
    // return lastIdsControllers[n - 1];
    return currentLastId;
  }

  function checkLastId(uint256 _id) public returns(bool) {
    if (_id == currentLastId) {
      return true;
    } else {
      false;
    }
  }

//   function _witnetUpgradeDataRequest(uint256 _id, uint256 _tallyReward) public payable {
//     witnetUpgradeRequest(_id, _tallyReward);
//   }

//   function _witnetReadResult (uint256 _id) public view returns(bytes memory) {
//     return witnetReadResult(_id);
//   }
}
