pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../../contracts/NewBlockRelay.sol";
import "../../contracts/ActiveBridgeSetLib.sol";

/**
 * @title Test Helper for the new block Relay contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of new block relay contract functions for testing purposes
 * @author Witnet Foundation
 */


contract NewBRTestHelper is NewBlockRelay {
  NewBlockRelay br;
  uint256 timestamp;
  uint256 witnetGenesis;
  uint256 firstBlock;

  using ActiveBridgeSetLib for ActiveBridgeSetLib.ActiveBridgeSet;

  constructor (uint256 _witnetGenesis, uint256 _epochSeconds, uint256 _firstBlock)
  NewBlockRelay(_witnetGenesis, _epochSeconds, _firstBlock) public {}

  // Pushes the activity in the ABS
  function pushActivity(uint256 _blockNumber) public {
    address _address = msg.sender;
    abs.pushActivity(_address, _blockNumber);
  }

  // Updates the currentEpoch
  function updateEpoch() public view returns (uint256) {
    return currentEpoch;
  }

  // Sets the current epoch to be the next
  function nextEpoch() public {
    currentEpoch = currentEpoch + 1;
  }

  // Sets the currentEpoch
  function setEpoch(uint256 _epoch) public returns (uint256) {
    currentEpoch = _epoch;
  }

  // Sets the number of members in the ABS
  function setAbsIdentitiesNumber(uint256 _identitiesNumber) public returns (uint256) {
    activeIdentities = _identitiesNumber;
  }

  // Sets the previous epoch as finalized
  function setPreviousEpochFinalized() public {
    epochFinalizedBlock[currentEpoch - 2].status = "Finalized";
  }

  // Gets the vote with the poposeBlock inputs
  function getVote(
    uint256 _blockHash,
    uint256 _epoch,
    uint256 _drMerkleRoot,
    uint256 _tallyMerkleRoot,
    uint256 _previousVote) public returns(uint256)
    {
    uint256 vote = uint256(
      sha256(
        abi.encodePacked(
      _blockHash,
      _epoch,
      _drMerkleRoot,
      _tallyMerkleRoot,
      _previousVote)));

    return vote;

  }

  // Gets the blockHash of a vote finalized in a specific epoch
  function getBlockHash(uint256 _epoch) public  returns (uint256) {
    uint256 blockHash = epochFinalizedBlock[_epoch].blockHash;
    return blockHash;
  }

  // Gets the length of the candidates array
  function getCandidatesLength() public view returns (uint256) {
    return candidates.length;
  }

  // Checks if the cuurentEpoch - 2 in pending
  function checkStatusPending() public returns (bool) {
    string memory pending = "Pending";
    //emit EpochStatus(epochStatus[currentEpoch-2])
    if (keccak256(abi.encodePacked((epochFinalizedBlock[currentEpoch - 2].status))) == keccak256(abi.encodePacked((pending)))) {
      return true;
    }
  }

  // Checks if the cuurentEpoch - 2 in pending
  function checkStatusFinalized() public returns (bool) {
    string memory finalized = "Finalized";
    //emit EpochStatus(epochStatus[currentEpoch-2])
    if (keccak256(abi.encodePacked((epochFinalizedBlock[currentEpoch - 2].status))) == keccak256(abi.encodePacked((finalized)))) {
      return true;
    }
  }

}