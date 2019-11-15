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
  uint256 blockHash;
  uint256 epoch;

  constructor (
    address _wbiRelayAddress,
    uint8 _repFactor)
  WitnetBridgeInterface(_wbiRelayAddress, _repFactor) public { }

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

  function _verifyPoe(
    uint256[4] memory _poe,
    uint256[2] memory _publicKey,
    uint256[2] memory _uPoint,
    uint256[4] memory _vPointHelpers)
  public view returns(bool)
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
    return abi.encodePacked(blockHash, epoch);
  }

  function setActiveIdentities(uint32 _abs)
    public
  {
    abs.activeIdentities = _abs;
  }

  function fastVerify(
    uint256[2] memory _publicKey,
    uint256[4] memory _proof,
    bytes memory _message,
    uint256[2] memory _uPoint,
    uint256[4] memory _vComponents)
  public pure returns (bool)
  {
    return true;
  }

  function gammaToHash(uint256 _gammaX, uint256 _gammaY) public pure returns (bytes32) {
    return bytes32(_gammaX);
  }

}
