pragma solidity ^0.5.0;

import "./ActiveBridgeSetLib.sol";
import "./WitnetBridgeInterface.sol";


/**
 * @title New Block relay contract
 * @notice Contract to store/read block headers from the Witnet network
 * @author Witnet Foundation
 */
contract NewBlockRelay is WitnetBridgeInterface {

  struct MerkleRoots {
    // hash of the merkle root of the DRs in Witnet
    uint256 drHashMerkleRoot;
    // hash of the merkle root of the tallies in Witnet
    uint256 tallyHashMerkleRoot;
    // Vote for the previous block hash
    uint256 previousVote;
  }

  struct Beacon {
    // hash of the last block
    uint256 blockHash;
    // epoch of the last block
    uint256 epoch;
  }

  // Struct with the hashes of a votation
  struct Hashes {
    uint256 blockHash;
    uint256 drMerkleRoot;
    uint256 tallyMerkleRoot;
    uint256 previousVote;
    uint256 epoch;
  }

  struct VoteInfo {
    uint256 numberOfVotes;
    Hashes voteHashes;
  }

  // Array with the votes for the proposed blocks
  uint256[] public candidates;

  // Initializes the block with the maximum number of votes
  uint256 winnerVote;
  uint256 winnerId = 0;
  uint256 winnerDrMerkleRoot = 0;
  uint256 winnerTallyMerkleRoot = 0;
  uint256 winnerEpoch = 0;

  // Needed for the constructor
  uint256 witnetGenesis;
  uint256 epochSeconds;
  uint256 firstBlock;

  // Initializes the current epoch and the epoch in which it is valid to propose blocks
  uint256 currentEpoch;
  uint256 proposalEpoch;

  uint256 activeIdentities = uint256(abs.activeIdentities);

  // Last block reported
  Beacon public lastBlock;

  // Map a vote proposed to the number of votes recieved and its hashes
  mapping(uint256=> VoteInfo) internal voteInfo;

  /* Map the hash of the block to the merkle roots.
  It is used as an easy way to check if a blockHash already exists*/
  mapping (uint256 => MerkleRoots) public blocks;

  // Map an epoch to the finalized blockHash
  mapping(uint256 => uint256) internal epochFinalizedBlock;

  constructor(uint256 _witnetGenesis, uint256 _epochSeconds, uint256 _firstBlock) WitnetBridgeInterface(address(this), 2) public{
    // Set the first epoch in Witnet plus the epoch duration when deploying the contract
    witnetGenesis = _witnetGenesis;
    epochSeconds = _epochSeconds;
    firstBlock = _firstBlock;
  }

  // Ensures block exists
  modifier blockExists(uint256 _id){
    require(blocks[_id].drHashMerkleRoot!=0, "Non-existing block");
    _;
  }
   // Ensures block does not exist
  modifier blockDoesNotExist(uint256 _id){
    require(blocks[_id].drHashMerkleRoot==0, "The block already existed");
    _;
  }

   //  Ensures that neither Poi nor PoE are allowed if the epoch is pending
  modifier finalizedEpoch2(uint256 _epoch){
    require(
      (epochFinalizedBlock[_epoch] != 0),
      "The block has not been finalized");
    _;
  }

   //  Ensures that the msg.sender is in the abs
  modifier absMembership(address _address){
    require(abs.absMembership(_address) == true, "Not a member of the abs");
    _;
  }

/* Ensures the epoch for which the block is been proposed is valid
   Valid if it is one epoch before the current epoch */
  modifier validEpoch(uint256 _epoch){
    currentEpoch = updateEpoch();
    if (proposalEpoch == 0) {
      proposalEpoch = currentEpoch;
    }
    require(currentEpoch - 1 == _epoch, "Proposing a block for a non valid epoch");
    _;
  }

  /// @dev Updates the epoch
  function updateEpoch() public view returns(uint256) {
    return (block.timestamp - witnetGenesis)/epochSeconds;
  }

  /// @dev Retrieve the requests-only merkle root hash that was reported for a specific block header.
  /// @param _blockHash Hash of the block header
  /// @return Requests-only merkle root hash in the block header.
  function readDrMerkleRoot(uint256 _blockHash)
    public
    view
    blockExists(_blockHash)
  returns(uint256 drMerkleRoot)
    {
    drMerkleRoot = blocks[_blockHash].drHashMerkleRoot;
  }

  /// @dev Retrieve the tallies-only merkle root hash that was reported for a specific block header.
  /// @param _blockHash Hash of the block header
  /// tallies-only merkle root hash in the block header.
  function readTallyMerkleRoot(uint256 _blockHash)
    public
    view
    blockExists(_blockHash)
  returns(uint256 tallyMerkleRoot)
  {
    tallyMerkleRoot = blocks[_blockHash].tallyHashMerkleRoot;
  }

  /// @dev Read the beacon of the last block inserted
  /// @return bytes to be signed by bridge nodes
  function getLastBeacon()
    public
    view
  returns(bytes memory)
  {
    return abi.encodePacked(lastBlock.blockHash, lastBlock.epoch);
  }

/// @dev Verifies the validity of a PoI against the DR merkle root
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..]
  /// @param _blockHash the blockHash
  /// @param _index the index in the merkle tree of the element to verify
  /// @param _element the leaf to be verified
  /// @return true or false depending the validity
  function verifyDrPoi(
    uint256[] memory _poi,
    uint256 _blockHash,
    uint256 _index,
    uint256 _element)
  public
  view
  blockExists(_blockHash)
  finalizedEpoch2(currentEpoch)
  returns(bool)
  {
    uint256 drMerkleRoot = blocks[_blockHash].drHashMerkleRoot;
    return(verifyPoi(
      _poi,
      drMerkleRoot,
      _index,
      _element));
  }

  /// @dev Verifies the validity of a PoI against the tally merkle root
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..]
  /// @param _blockHash the blockHash
  /// @param _index the index in the merkle tree of the element to verify
  /// @param _element the element
  /// @return true or false depending the validity
  function verifyTallyPoi(
    uint256[] memory _poi,
    uint256 _blockHash,
    uint256 _index,
    uint256 _element)
  public
  view
  blockExists(_blockHash)
  returns(bool)
  {
    uint256 tallyMerkleRoot = blocks[_blockHash].tallyHashMerkleRoot;
    return(verifyPoi(
      _poi,
      tallyMerkleRoot,
      _index,
      _element));

  }

   /// @dev Proposes a block into the block relay
  /// @param _blockHash Hash of the block header
  /// @param _epoch Epoch for which the block is proposed
  /// @param _drMerkleRoot Merkle root belonging to the data requests
  /// @param _tallyMerkleRoot Merkle root belonging to the tallies
  /// @param _previousVote Hash of block's hashes proposed in the previous epoch
  function proposeBlock(
    uint256 _blockHash,
    uint256 _epoch,
    uint256 _drMerkleRoot,
    uint256 _tallyMerkleRoot,
    uint256 _previousVote
    )
    public
    validEpoch(_epoch)
    absMembership(msg.sender)
    returns(bytes32)
  {
    // If the porposal epoch chancges try to post the block with more votes
    if (currentEpoch > proposalEpoch) {
      // If it has not, the set the epoch to pending
      if (3*voteInfo[winnerVote].numberOfVotes >= 2*activeIdentities) {
      // If it has achieved consensus, post the block
        postNewBlock(
          winnerVote,
          winnerId,
          winnerEpoch,
          winnerDrMerkleRoot,
          winnerTallyMerkleRoot,
          voteInfo[winnerVote].voteHashes.previousVote);
      }
      // Set the winner values to 0
      winnerVote = 0;
      winnerId = 0;
      winnerEpoch = 0;
      winnerDrMerkleRoot = 0;
      winnerTallyMerkleRoot = 0;
      // Update the proposal epoch
      proposalEpoch = currentEpoch;
    }

    // Hash of the elements of the votation
    uint256 vote = uint256(
      sha256(
        abi.encodePacked(
      _blockHash,
      _epoch,
      _drMerkleRoot,
      _tallyMerkleRoot,
      _previousVote)));
    if (voteInfo[vote].numberOfVotes == 0) {
      // Add the vote to candidates
      candidates.push(vote);
      // Mapping the vote into its hashes
      voteInfo[vote].voteHashes.blockHash = _blockHash;
      voteInfo[vote].voteHashes.drMerkleRoot = _drMerkleRoot;
      voteInfo[vote].voteHashes.tallyMerkleRoot = _tallyMerkleRoot;
      voteInfo[vote].voteHashes.previousVote = _previousVote;
      voteInfo[vote].voteHashes.epoch = _epoch;
    }

    // Sum one vote
    voteInfo[vote].numberOfVotes += 1;
    // Update the block with more votes
    if (vote != winnerVote) {
      // Set as new winner if it has more votes
      if (voteInfo[vote].numberOfVotes > voteInfo[winnerVote].numberOfVotes) {
        winnerVote = vote;
        winnerId = _blockHash;
        winnerEpoch = _epoch;
        winnerDrMerkleRoot = _drMerkleRoot;
        winnerTallyMerkleRoot = _tallyMerkleRoot;
        //epochFinalizedBlock[_epoch].finalized = false;
    }

    }

    return bytes32(vote);

  }

  /// @dev Post new block into the block relay
  /// @param _vote Vote created when the block was proposed
  /// @param _blockHash Hash of the block headerPost
  /// @param _epoch Witnet epoch to which the block belongs to
  /// @param _drMerkleRoot Merkle root belonging to the data requests
  /// @param _tallyMerkleRoot Merkle root belonging to the tallies
  /// @param _previousVote Hash of block's hashes proposed in the previous epoch
  function postNewBlock(
    uint256 _vote,
    uint256 _blockHash,
    uint256 _epoch,
    uint256 _drMerkleRoot,
    uint256 _tallyMerkleRoot,
    uint256 _previousVote)
    private
    blockDoesNotExist(_blockHash)
  {
    // Map the epoch to the vote's Hashes
    epochFinalizedBlock[_epoch] = voteInfo[_vote].voteHashes.blockHash;
    blocks[_blockHash].drHashMerkleRoot = _drMerkleRoot;
    blocks[_blockHash].tallyHashMerkleRoot = _tallyMerkleRoot;
    blocks[_blockHash].previousVote = _previousVote;

    // Select previous vote and corresponding epoch
    uint256 previousVote = blocks[epochFinalizedBlock[_epoch]].previousVote;
    uint256 epoch = voteInfo[previousVote].voteHashes.epoch;

    // Finalize the previous votes when the corresponding epochs are bigger than the last finalized epoch
    while (epoch > lastBlock.epoch) {
      uint256 previousBlockHash = voteInfo[previousVote].voteHashes.blockHash;
      // Finalize the epoch
      epochFinalizedBlock[epoch] = previousBlockHash;
      // Map the block hash to its hashes
      blocks[previousBlockHash].drHashMerkleRoot = voteInfo[previousVote].voteHashes.drMerkleRoot;
      blocks[previousBlockHash].tallyHashMerkleRoot = voteInfo[previousVote].voteHashes.tallyMerkleRoot;
      blocks[previousBlockHash].previousVote = voteInfo[previousVote].voteHashes.previousVote;
      // Update previousVote and epoch
      previousVote = blocks[previousBlockHash].previousVote;
      epoch = voteInfo[previousVote].voteHashes.epoch;
    }
    if (epoch == lastBlock.epoch) {
      // Revert if the previousvote is not equal the last beacon
      if (voteInfo[previousVote].voteHashes.blockHash != lastBlock.blockHash) {
        revert("NOT valid previous block proposed");
        }
      }

    // Post the last block
    lastBlock.blockHash = _blockHash;
    lastBlock.epoch = _epoch;

    // Delete the condidates array so its empty for next epoch
    for (uint i = 0; i <= candidates.length - 1; i++) {
      delete voteInfo[candidates[i]].voteHashes;}
    delete candidates;
  }

  /// @dev Verifies the validity of a PoI
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..]
  /// @param _root the merkle root
  /// @param _index the index in the merkle tree of the element to verify
  /// @param _element the leaf to be verified
  /// @return true or false depending the validity
  function verifyPoi(
    uint256[] memory _poi,
    uint256 _root,
    uint256 _index,
    uint256 _element)
  private pure returns(bool)
  {
    uint256 tree = _element;
    uint256 index = _index;
    // We want to prove that the hash of the _poi and the _element is equal to _root
    // For knowing if concatenate to the left or the right we check the parity of the the index
    for (uint i = 0; i<_poi.length; i++) {
      if (index%2 == 0) {
        tree = uint256(sha256(abi.encodePacked(tree, _poi[i])));
      } else {
        tree = uint256(sha256(abi.encodePacked(_poi[i], tree)));
      }
      index = index>>1;
    }
    return _root==tree;
  }

}
