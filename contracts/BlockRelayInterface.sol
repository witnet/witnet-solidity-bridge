pragma solidity ^0.5.0;


/**
 * @title Block Relay Interface
 * @notice Interface of a Block Relay to a Witnet network
 * It defines how to interact with the Block Relay in order to support:
 *  - Retrieve last beacon information
 *  - Verify proof of inclusions (PoIs) of data request and tally transactions
 * @author Witnet Foundation
 */
interface BlockRelayInterface {

  /// @notice Returns the beacon from the last inserted block.
  /// The last beacon (in bytes) will be used by Witnet Bridge nodes to compute their eligibility.
  /// @return last beacon in bytes
  function getLastBeacon() external view returns(bytes memory);

  /// @notice Verifies the validity of a data request PoI against the DR merkle root
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..]
  /// @param _blockHash the blockHash
  /// @param _index the index in the merkle tree of the element to verify
  /// @param _element the leaf to be verified
  /// @return true if valid data request PoI
  function verifyDrPoi(
    uint256[] calldata _poi,
    uint256 _blockHash,
    uint256 _index,
    uint256 _element) external view returns(bool);

  /// @notice Verifies the validity of a tally PoI against the Tally merkle root
  /// @param _poi the proof of inclusion as [sibling1, sibling2,..]
  /// @param _blockHash the blockHash
  /// @param _index the index in the merkle tree of the element to verify
  /// @param _element the leaf to be verified
  /// @return true if valid tally PoI
  function verifyTallyPoi(
    uint256[] calldata _poi,
    uint256 _blockHash,
    uint256 _index,
    uint256 _element) external view returns(bool);

}