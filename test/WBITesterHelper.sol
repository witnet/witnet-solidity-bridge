pragma solidity ^0.5.0;

import "../contracts/./WitnetBridgeInterface.sol";


/**
 * @title Test Helper for the WBI contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of wbi contract functions for testing purposes
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

  function _verifySig(
    bytes memory message,
    uint256[2] memory _publicKey,
    bytes memory _addrSignature
  )
  public returns(bool){
    return verifySig(
      message,
      _publicKey,
      _addrSignature);
  }
}