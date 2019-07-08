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
  function readDrMerkleRoot(uint256 _blockHash) public view returns(uint256 drMerkleRoot) {
    if(blocks[_blockHash].drHashMerkleRoot==0) {
      revert("Non-existing block");
    }
    else{
      drMerkleRoot = blocks[_blockHash].drHashMerkleRoot;
    }
  }

  // @dev Read the tally merkle root
  /// @param _blockHash Hash of the block header
  /// merkle root for the tallies in the block header
  function readTallyMerkleRoot(uint256 _blockHash) public view returns(uint256 tallyMerkleRoot) {
    if(blocks[_blockHash].tallyHashMerkleRoot==0) {
      revert("Non-existing block");
    }
    else{
      tallyMerkleRoot = blocks[_blockHash].tallyHashMerkleRoot;
    }
  }
}
