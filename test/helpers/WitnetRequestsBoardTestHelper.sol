pragma solidity ^0.5.0;

import "../../contracts/WitnetRequestsBoard.sol";


/**
 * @title Test Helper for the WRB contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of wrb contract functions for testing purposes
 * @author Witnet Foundation
 */


contract WitnetRequestsBoardTestHelper is WitnetRequestsBoard {
  WitnetRequestsBoard wrb;
  //uint256 blockHash;
  // epoch of the last block
  //uint256 epoch;
  uint256 blockHash;
  uint256 epoch;

  constructor (
    address _blockRelayAddress,
    uint8 _repFactor)
  WitnetRequestsBoard(_blockRelayAddress, _repFactor) public { }

  modifier vrfValid(
    uint256[4] memory _poe,
    uint256[2] memory _publicKey,
    uint256[2] memory _uPoint,
    uint256[4] memory _vPointHelpers) {
    require(
      true,
      "Not a valid VRF");
    _;
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

}
