// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "../../contracts/WitnetRequestsBoard.sol";


/**
 * @title Test Helper for the WRB contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of wrb contract functions for testing purposes
 * @author Witnet Foundation
 */


contract WitnetRequestsBoardTestHelper is WitnetRequestsBoard {

  WitnetRequestsBoard internal wrb;
  uint256 internal blockHash;
  uint256 internal epoch;

  constructor(address _blockRelayAddress, uint8 _repFactor) public WitnetRequestsBoard(_blockRelayAddress, _repFactor) { }

  modifier vrfValid (
    uint256[4] memory _poe,
    uint256[2] memory _publicKey,
    uint256[2] memory _uPoint,
    uint256[4] memory _vPointHelpers) override {
    require(
      true,
      "Not a valid VRF");
    _;
  }

  function _verifyPoe(
    uint256[4] calldata _poe,
    uint256[2] calldata _publicKey,
    uint256[2] calldata _uPoint,
    uint256[4] calldata _vPointHelpers)
    external
    view
  returns(bool)
  {
    return verifyPoe(
      _poe,
      _publicKey,
      _uPoint,
      _vPointHelpers);
  }

  function _verifySig(
    bytes calldata _message,
    uint256[2] calldata _publicKey,
    bytes calldata _addrSignature)
    external
  returns(bool)
  {
    return verifySig(
      _message,
      _publicKey,
      _addrSignature);
  }

  function setActiveIdentities(uint32 _abs)
    external
  {
    abs.activeIdentities = _abs;
  }

  function getLastBeacon() public view override returns(bytes memory) {
    return abi.encodePacked(blockHash, epoch);
  }

}
