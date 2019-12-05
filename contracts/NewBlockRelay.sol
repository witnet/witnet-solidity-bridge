pragma solidity ^0.5.0;

import "./ActiveBridgeSetLib.sol";
import "./WitnetBridgeInterface.sol";


/**
 * @title New Block relay contract
 * @notice Contract to store/read block headers from the Witnet network
 * @author Witnet Foundation
 */
contract NewBlockRelay is WitnetBridgeInterface {

  using ActiveBridgeSetLib for ActiveBridgeSetLib.ActiveBridgeSet;

  struct MerkleRoots {
    // hash of the merkle root of the DRs in Witnet
    uint256 drHashMerkleRoot;
    // hash of the merkle root of the tallies in Witnet
    uint256 tallyHashMerkleRoot;
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
  }

  struct FinalizedBlock {
    string status;
    uint256 blockHash;
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

  // Initializes the tied vote count
  uint256 tiedVote;

  uint256 activeIdentities = uint256(abs.activeIdentities);

  // Last block reported
  Beacon public lastBlock;

  // Map a vote proposed to the number of votes recieved and its hashes
  mapping(uint256=> VoteInfo) internal voteInfo;

  /* Map the hash of the block to the merkle roots.
  It is used as an easy way to check if a blockHash already exists*/
  mapping (uint256 => MerkleRoots) public blocks;

  // Map an epoch to the finalized block
  mapping(uint256 => FinalizedBlock) internal epochFinalizedBlock;

 // Event emitted when there's been a tie during the votation process
  event Tie(string _tie);

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
  modifier finalizedEpoch(uint256 _epoch){
    require(
      keccak256(abi.encodePacked((epochFinalizedBlock[_epoch].status))) ==
      keccak256(abi.encodePacked(("Finalized"))),
      "The block has not been finalized");
    _;
  }

   //  Ensures that the msg.sender is in the abs
  modifier absMembership(address _address){
    require(abs.absMembership(_address) == true, "Not a member of the abs");
    _;
  }


  modifier noTie(){
    if (tiedVote != winnerVote) {
      require(voteInfo[tiedVote].numberOfVotes < voteInfo[winnerVote].numberOfVotes, "There has been a tie");
    }
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

  /// @dev Proposes a block into the block relay
  /// @param _blockHash Hash of the block header
  /// @param _epoch Epoch for which the block is proposed
  /// @param _drMerkleRoot Merkle root belonging to the data requests
  /// @param _tallyMerkleRoot Merkle root belonging to the tallies
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
    // Post new block if the proposal epoch has changed
    if (currentEpoch > proposalEpoch) {

      postNewBlock(
        winnerVote,
        winnerId,
        winnerEpoch,
        winnerDrMerkleRoot,
        winnerTallyMerkleRoot,
        voteInfo[winnerVote].voteHashes.previousVote);
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
    }

    // Sum one vote
    voteInfo[vote].numberOfVotes += 1;
    // Check if there is a tie
    if (vote != winnerVote) {
      if (voteInfo[vote].numberOfVotes == voteInfo[winnerVote].numberOfVotes) {
        emit Tie("there is been a tie");
        tiedVote = vote;
      }
      // Set as new winner if it has more votes
      if (voteInfo[vote].numberOfVotes > voteInfo[winnerVote].numberOfVotes) {
        winnerVote = vote;
        winnerId = _blockHash;
        winnerEpoch = _epoch;
        winnerDrMerkleRoot = _drMerkleRoot;
        winnerTallyMerkleRoot = _tallyMerkleRoot;
    }

    }

    return bytes32(vote);

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
  finalizedEpoch(currentEpoch)
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

  /// @dev Post new block into the block relay
  /// @param _blockHash Hash of the block headerPost
  /// @param _epoch Witnet epoch to which the block belongs to
  /// @param _drMerkleRoot Merkle root belonging to the data requests
  /// @param _tallyMerkleRoot Merkle root belonging to the tallies
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
    if (3*voteInfo[winnerVote].numberOfVotes < 2*activeIdentities) {
      epochFinalizedBlock[_epoch].status = "Pending";
      // Set the winner values to 0
      winnerVote = 0;
      winnerId = 0;
      winnerEpoch = 0;
      winnerDrMerkleRoot = 0;
      winnerTallyMerkleRoot = 0;
    } else {
      // Map the epoch to the vote's Hashes
      epochFinalizedBlock[_epoch].status = "Finalized";
      epochFinalizedBlock[_epoch].blockHash = voteInfo[_vote].voteHashes.blockHash;
      blocks[_blockHash].drHashMerkleRoot = _drMerkleRoot;
      blocks[_blockHash].tallyHashMerkleRoot = _tallyMerkleRoot;
      blocks[_blockHash].previousVote = _previousVote;
      // Check if the status of the previous block is Pending and so it needs to be finalized
      if (keccak256(abi.encodePacked((epochFinalizedBlock[_epoch-1].status))) == keccak256(abi.encodePacked(("Pending")))) {
        uint x;
        // Select the last Finalized epoch
        for (uint i; i>=0; i++) {
          if (keccak256(abi.encodePacked(epochFinalizedBlock[_epoch-i-1].status)) != keccak256(abi.encodePacked(("Finalized")))) {
            x = i;
            uint256 previousFinalVote;
            // Finalize the previous epochs with the corresponding previous votes and hashes
            previousFinalVote = blocks[epochFinalizedBlock[_epoch-i].blockHash].previousVote;
            epochFinalizedBlock[_epoch - i-1].blockHash = voteInfo[previousFinalVote].voteHashes.blockHash;
            uint256 previousBlockHash = voteInfo[previousFinalVote].voteHashes.blockHash;
            blocks[previousBlockHash].drHashMerkleRoot = voteInfo[previousFinalVote].voteHashes.drMerkleRoot;
            blocks[previousBlockHash].tallyHashMerkleRoot = voteInfo[previousFinalVote].voteHashes.tallyMerkleRoot;
            // Set the previous status to Finalized
            epochFinalizedBlock[_epoch-i-1].status = "Finalized";
          } else if (keccak256(abi.encodePacked((epochFinalizedBlock[_epoch-i-1].status))) == keccak256(abi.encodePacked(("Finalized")))) {
            break;
          }
        }
        // Post each block as last beacon, from the oldest to the newest
        for (uint j; j <= x-1; j++) {
          lastBlock.blockHash = epochFinalizedBlock[_epoch - x + j].blockHash;
          lastBlock.epoch = _epoch - x + j;
        }
       }
       // Post the last block
      lastBlock.blockHash = _blockHash;
      lastBlock.epoch = _epoch;

    // Set the winner values equal 0
      winnerId = 0;
      winnerVote = 0;
      winnerId = 0;
      winnerEpoch = 0;
      winnerDrMerkleRoot = 0;
      winnerTallyMerkleRoot = 0;
      // Delete the condidates array so its empty for next epoch
      for (uint i = 0; i <= candidates.length - 1; i++) {
        delete voteInfo[candidates[i]].voteHashes;}
      delete candidates;
  }
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
