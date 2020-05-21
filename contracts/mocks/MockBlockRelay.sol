// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "witnet-ethereum-block-relay/contracts/BlockRelayInterface.sol";


/**
 * @title Block relay contract
 * @notice Contract to store/read block headers from the Witnet network.
 * @author Witnet Foundation
 */
contract MockBlockRelay is BlockRelayInterface {

  struct MerkleRoots {
    // hash of the merkle root of the DRs in Witnet
    uint256 drHashMerkleRoot;
    // hash of the merkle root of the tallies in Witnet
    uint256 tallyHashMerkleRoot;
  }

  struct Beacon {
    // hash of the last block
    uint256 blockHash;
    // epoch of the last block
    uint256 epoch;
  }

  // Address of the block pusher
  address public witnet;
  // Last block reported
  Beacon public lastBlock;

  mapping (uint256 => MerkleRoots) public blocks;

  // Event emitted when a new block is posted to the contract
  event NewBlock(address indexed _from, uint256 _id);

  // Only the owner should be able to push blocks
  modifier isOwner() {
    require(msg.sender == witnet, "Sender not authorized"); // If it is incorrect here, it reverts.
    _; // Otherwise, it continues.
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

  constructor() public{
    // Only the contract deployer is able to push blocks
    witnet = msg.sender;
  }

  /// @dev Read the beacon of the last block inserted.
  /// @return bytes to be signed by bridge nodes.
  function getLastBeacon()
    external
    view
    override
  returns(bytes memory)
  {
    return abi.encodePacked(lastBlock.blockHash, lastBlock.epoch);
  }

  /// @notice Returns the lastest epoch reported to the block relay.
  /// @return the last epoch.
  function getLastEpoch() external view override returns(uint256) {
    return lastBlock.epoch;
  }

  /// @notice Returns the latest hash reported to the block relay.
  /// @return the last block hash.
  function getLastHash() external view override returns(uint256) {
    return lastBlock.blockHash;
  }

  /// @dev Verifies the validity of a PoI against the DR merkle root.
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..].
  /// @param _blockHash the blockHash.
  /// @param _index the index in the merkle tree of the element to verify.
  /// @param _element the leaf to be verified.
  /// @return true or false depending the validity.
  function verifyDrPoi(
    uint256[] calldata _poi,
    uint256 _blockHash,
    uint256 _index,
    uint256 _element)
    external
    view
    blockExists(_blockHash)
    override
  returns(bool)
  {
    uint256 drMerkleRoot = blocks[_blockHash].drHashMerkleRoot;
    return(verifyPoi(
      _poi,
      drMerkleRoot,
      _index,
      _element));
  }

  /// @dev Verifies the validity of a PoI against the tally merkle root.
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..].
  /// @param _blockHash the blockHash.
  /// @param _index the index in the merkle tree of the element to verify.
  /// @param _element the element.
  /// @return true or false depending the validity.
  function verifyTallyPoi(
    uint256[] calldata _poi,
    uint256 _blockHash,
    uint256 _index,
    uint256 _element)
    external
    view
    blockExists(_blockHash)
    override
  returns(bool)
  {
    uint256 tallyMerkleRoot = blocks[_blockHash].tallyHashMerkleRoot;
    return(verifyPoi(
      _poi,
      tallyMerkleRoot,
      _index,
      _element));
  }

  /// @dev Determines if the contract is upgradable.
  /// @return true if the contract is upgradable.
  function isUpgradable(address) external view override returns(bool) {
    return true;
  }

  /// @dev Post new block into the block relay.
  /// @param _blockHash Hash of the block header.
  /// @param _epoch Witnet epoch to which the block belongs to.
  /// @param _drMerkleRoot Merkle root belonging to the data requests.
  /// @param _tallyMerkleRoot Merkle root belonging to the tallies.
  function postNewBlock(
    uint256 _blockHash,
    uint256 _epoch,
    uint256 _drMerkleRoot,
    uint256 _tallyMerkleRoot)
    external
    isOwner
    blockDoesNotExist(_blockHash)
  {
    uint256 id = _blockHash;
    lastBlock.blockHash = id;
    lastBlock.epoch = _epoch;
    blocks[id].drHashMerkleRoot = _drMerkleRoot;
    blocks[id].tallyHashMerkleRoot = _tallyMerkleRoot;
    emit NewBlock(witnet, id);
  }

  /// @dev Retrieve the requests-only merkle root hash that was reported for a specific block header.
  /// @param _blockHash Hash of the block header.
  /// @return Requests-only merkle root hash in the block header.
  function readDrMerkleRoot(uint256 _blockHash)
    external
    view
    blockExists(_blockHash)
  returns(uint256)
  {
    return blocks[_blockHash].drHashMerkleRoot;
  }

  /// @dev Retrieve the tallies-only merkle root hash that was reported for a specific block header.
  /// @param _blockHash Hash of the block header.
  /// tallies-only merkle root hash in the block header.
  function readTallyMerkleRoot(uint256 _blockHash)
    external
    view
    blockExists(_blockHash)
  returns(uint256)
  {
    return blocks[_blockHash].tallyHashMerkleRoot;
  }

  /// @dev Verifies the validity of a PoI.
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..].
  /// @param _root the merkle root.
  /// @param _index the index in the merkle tree of the element to verify.
  /// @param _element the leaf to be verified.
  /// @return true or false depending the validity.
  function verifyPoi(
    uint256[] memory _poi,
    uint256 _root,
    uint256 _index,
    uint256 _element)
  private pure returns(bool)
  {
    uint256 tree = _element;
    uint256 index = _index;
    // We want to prove that the hash of the _poi and the _element is equal to _root.
    // For knowing if concatenate to the left or the right we check the parity of the the index.
    for (uint i = 0; i < _poi.length; i++) {
      if (index%2 == 0) {
        tree = uint256(sha256(abi.encodePacked(tree, _poi[i])));
      } else {
        tree = uint256(sha256(abi.encodePacked(_poi[i], tree)));
      }
      index = index >> 1;
    }
    return _root == tree;
  }
}