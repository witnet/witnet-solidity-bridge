pragma solidity ^0.5.0;

contract BlockRelay {

  struct MerkleRoots {
    // hash of the merkle root of the DRs in Witnet
    uint256 drHashMerkleRoot;
    // hash of the merkle root of the tallies in Witnet
    uint256 tallyHashMerkleRoot;
  }
  // Address of the block pusher
  address witnet;

  mapping (uint256 => MerkleRoots) public blocks;

  event NewBlock(address indexed _from, uint256 _id);

  constructor() public{
    // Only the contract deployer is able to push blocks
    witnet = msg.sender;
  }

  //only the owner should be able to push blocks
  modifier isOwner() {
    require(msg.sender == witnet, "Sender not authorized"); // If it is incorrect here, it reverts.
    _; // Otherwise, it continues.
  }
  //ensures block exists
  modifier blockExists(uint256 _id){
    require(blocks[_id].drHashMerkleRoot!=0, "Non-existing block");
    _;
  }
   //ensures block does not exist
  modifier blockNotExists(uint256 _id){
    require(blocks[_id].drHashMerkleRoot==0, "Existing block");
    _;
  }

  // @dev Post new block in the block relay
  /// @param _blockHash Hash of the block header
  /// @param _drMerkleRoot Merkle root belonging to the data requests
  /// @param _tallyMerkleRoot Merkle root belonging to the tallies
  function postNewBlock(uint256 _blockHash, uint256 _drMerkleRoot, uint256 _tallyMerkleRoot)
    public
    isOwner
    blockNotExists(_blockHash)
  {
    uint256 id = _blockHash;
    if(blocks[id].drHashMerkleRoot!=0) {
      revert("Existing block");
    }
    else{
      blocks[id].drHashMerkleRoot = _drMerkleRoot;
      blocks[id].tallyHashMerkleRoot = _tallyMerkleRoot;
    }
  }

  // @dev Read the DR merkle root
  /// @param _blockHash Hash of the block header
  /// @return merkle root for the DR in the block header
  function readDrMerkleRoot(uint256 _blockHash)
    public
    view
    blockExists(_blockHash)
  returns(uint256 drMerkleRoot)
    {
    drMerkleRoot = blocks[_blockHash].drHashMerkleRoot;
  }

  // @dev Read the tally merkle root
  /// @param _blockHash Hash of the block header
  /// merkle root for the tallies in the block header
  function readTallyMerkleRoot(uint256 _blockHash)
    public
    view
    blockExists(_blockHash)
  returns(uint256 tallyMerkleRoot)
  {
    tallyMerkleRoot = blocks[_blockHash].tallyHashMerkleRoot;
  }
}
