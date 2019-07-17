pragma solidity ^0.5.0;

import "../contracts/./WitnetBridgeInterface.sol";


/**
 * @title Test Helper for the VRF contract
 * @dev The aim of this contract is twofold:
 * 1. Raise the visibility modifier of VRF contract functions for testing purposes
 * 2. Removal of the `pure` modifier to allow gas consumption analysis
 * @author Witnet Foundation
 */
contract WBITestHelper is WitnetBridgeInterface{
  WitnetBridgeInterface wbi;

  constructor (address _wbiRelayAddress) WitnetBridgeInterface(_wbiRelayAddress) public { }
  
  function _verifyPoi(
    uint256[] memory _poi,
    uint256 _root,
    uint256 _index,
    uint256 element)
  public pure returns(bool){
    return verifyPoi(
      _poi,
      _root,
      _index,
      element);
  }
}