pragma solidity ^0.5.0;

contract BlockRelay {

  struct MerkleRoots {
    uint256 dr_hash_merkle_root;
    uint256 tally_hash_merkle_root;
  }

  address witnet;

  mapping (uint256 => MerkleRoots) public blocks;

  event NewBlock(address indexed _from, uint256 _id);

  constructor() public{
    witnet = msg.sender;
  }

  modifier onlyWitnet() {
    require(msg.sender == witnet, "Sender not authorized"); // If it is incorrect here, it reverts.
    _; // Otherwise, it continues.
  }

  // @dev Post new block in the block relay
  /// @param _blockHash Hash of the block header
  /// @param _drMerkleRoot Merkle root belonging to the data requests
  /// @param _tallyMerkleRoot Merkle root belonging to the tallies
  function postNewBlock(uint256 _blockHash, uint256 _drMerkleRoot, uint256 _tallyMerkleRoot) public onlyWitnet {
    uint256 id = _blockHash;
    if(blocks[id].dr_hash_merkle_root!=0) {
      revert("Existing block");
    }
    else{
      blocks[id].dr_hash_merkle_root = _drMerkleRoot;
      blocks[id].tally_hash_merkle_root = _tallyMerkleRoot;
    }
  }

  // @dev Read the DR merkle root
  /// @param _blockHash Hash of the block header
  function readDrMerkleRoot(uint256 _blockHash) public view returns(uint256 drMerkleRoot) {
    if(blocks[_blockHash].dr_hash_merkle_root==0) {
      revert("Non-existing block");
    }
    else{
      drMerkleRoot = blocks[_blockHash].dr_hash_merkle_root;
    }

  }

  // @dev Read the tally merkle root
  /// @param _blockHash Hash of the block header
  function readTallyMerkleRoot(uint256 _blockHash) public view returns(uint256 tallyMerkleRoot) {
    if(blocks[_blockHash].tally_hash_merkle_root==0) {
      revert("Non-existing block");
    }
    else{
      tallyMerkleRoot = blocks[_blockHash].tally_hash_merkle_root;
    }
  }
}
