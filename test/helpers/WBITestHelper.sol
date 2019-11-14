pragma solidity ^0.5.0;

import "../../contracts/WitnetBridgeInterface.sol";


/**
 * @title Test Helper for the WBI contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of wbi contract functions for testing purposes
 * @author Witnet Foundation
 */


contract WBITestHelper is WitnetBridgeInterface {
  WitnetBridgeInterface wbi;
  //uint256 blockHash;
  // epoch of the last block
  //uint256 epoch;
  bytes lastBeacon;

  constructor (address _wbiRelayAddress) WitnetBridgeInterface(_wbiRelayAddress) public { }

  function _verifyPoi(
    uint256[] memory _poi,
    uint256 _root,
    uint256 _index,
    uint256 element
  )
  public pure returns(bool)
  {
    return verifyPoi(
      _poi,
      _root,
      _index,
      element);
  }

  function verifyPoe(
    uint256[4] memory _poe,
    uint256[2] memory _publicKey,
    uint256[2] memory _uPoint,
    uint256[4] memory _vPointHelpers)
  public pure returns(bool)
  {
    return verifyPoe(
      _poe,
      _publicKey,
      _uPoint,
      _vPointHelpers);
  }


  function _verifySig(
    bytes memory _message,
    uint256[2] memory _publicKey,
    bytes memory _addrSignature
  )
  public returns(bool)
  {
    return verifySig(
      _message,
      _publicKey,
      _addrSignature);
  }

  function getLastBeacon()
    public
    view
  returns(bytes memory)
  {
    //return abi.encodePacked(blockHash, epoch);ç
    return lastBeacon;
  }

  function setActiveIdentities(uint32 _abs)
    public
    view
  {
    ABS.activeIdentities = _abs;
  }
}
