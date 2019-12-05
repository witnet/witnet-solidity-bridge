pragma solidity ^0.5.0;


/**
 * @title Active Bridge Set (ABS) library
 * @notice This library counts the number of bridges that were active recently.
 */
library ActiveBridgeSetLib {

  // Number of Ethereum blocks during which identities can be pushed into a single activity slot
  uint8 public constant CLAIM_BLOCK_PERIOD = 8;

  // Number of activity slots in the ABS
  uint16 public constant ACTIVITY_LENGTH = 100;

  struct ActiveBridgeSet {
    // Mapping of activity slots with participating identities
    mapping (uint16 => address[]) epochIdentities;
    // Mapping of identities with their participation count
    mapping (address => uint16) identityCount;
    // Number of identities in the Active Bridge Set (consolidated during `ACTIVITY_LENGTH`)
    uint32 activeIdentities;
    // Number of identities for the next activity slot (to be updated in the next activity slot)
    uint32 nextActiveIdentities;
    // Last used block number during an activity update
    uint256 lastBlockNumber;
  }

  /// @dev Updates activity in Witnet without requiring protocol participation.
  /// @param _abs The Active Bridge Set structure to be updated.
  /// @param _blockNumber The block number up to which the activity should be updated.
  function updateActivity(ActiveBridgeSet storage _abs, uint256 _blockNumber) internal {
    (uint16 currentSlot, uint16 lastSlot, bool overflow) = getSlots(_abs, _blockNumber);

    // Avoid gas cost if ABS is up to date
    require(
      updateABS(
        _abs,
        currentSlot,
        lastSlot,
        overflow
      ), "The ABS was already up to date");

    _abs.lastBlockNumber = _blockNumber;
  }

  /// @dev Pushes activity updates through protocol activities (implying insertion of identity).
  /// @param _abs The Active Bridge Set structure to be updated.
  /// @param _address The address pushing the activity.
  /// @param _blockNumber The block number up to which the activity should be updated.
  function pushActivity(ActiveBridgeSet storage _abs, address _address, uint256 _blockNumber) internal returns (bool success) {
    (uint16 currentSlot, uint16 lastSlot, bool overflow) = getSlots(_abs, _blockNumber);

    // Update ABS and if it was already up to date, check if identities already counted
    if (
      updateABS(
        _abs,
        currentSlot,
        lastSlot,
        overflow
      ))
    {
      _abs.lastBlockNumber = _blockNumber;
    } else {
      // Check if address was already counted as active identity in this current activity slot
      for (uint i; i < _abs.epochIdentities[currentSlot].length; i++) {
        if (_abs.epochIdentities[currentSlot][i] == _address) {
          return false;
        }
      }
    }

    // Update current activity slot with identity:
    //  1. Add currentSlot to `epochIdentities` with address
    //  2. If count = 0, increment by 1 `nextActiveIdentities`
    //  3. Increment by 1 the count of the identity
    _abs.epochIdentities[currentSlot].push(_address);
    if (_abs.identityCount[_address] == 0) {
      _abs.nextActiveIdentities++;
    }
    _abs.identityCount[_address]++;

    return true;
  }

  /// @dev Checks if an address is a memeber of the ABS
  /// @param _abs The Active Bridge Set structure containing the last block.
  /// @param _address The address to check.
  /// @return true or false
  function absMembership(ActiveBridgeSet storage _abs, address _address) internal returns (bool) {
    uint256 blockNumber = block.number;
    (uint16 currentSlot, uint16 lastSlot, bool overflow) = getSlots(_abs, blockNumber);
    updateABS(
      _abs,
      currentSlot,
      lastSlot,
      overflow);
    for (uint i; i < _abs.epochIdentities[lastSlot].length;) {
      if (_abs.epochIdentities[lastSlot][i] == _address) {
        return true;
        }
      }
  }

  /// @dev Gets the slots of the last block seen by the ABS provided and the block number provided.
  /// @param _abs The Active Bridge Set structure containing the last block.
  /// @param _blockNumber The block number from which to get the current slot.
  /// @return (currentSlot, lastSlot, overflow), where overflow implies the block difference &gt; CLAIM_BLOCK_PERIOD* ACTIVITY_LENGTH
  function getSlots(ActiveBridgeSet storage _abs, uint256 _blockNumber) private view returns (uint16, uint16, bool) {
    // Get current activity slot number
    uint16 currentSlot = uint16((_blockNumber / CLAIM_BLOCK_PERIOD) % ACTIVITY_LENGTH);
    // Get last actitivy slot number
    uint16 lastSlot = uint16((_abs.lastBlockNumber / CLAIM_BLOCK_PERIOD) % ACTIVITY_LENGTH);
    // Check if there was an activity slot overflow
    bool overflow = (_blockNumber - _abs.lastBlockNumber) >= CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH;

    return (currentSlot, lastSlot, overflow);
  }

  /// @dev Updates the provided ABS according to the slots provided.
  /// @param _abs The Active Bridge Set to be updated.
  /// @param _currentSlot The current slot.
  /// @param _lastSlot The last slot seen by the ABS.
  /// @param _overflow Whether the current slot has overflown the last slot.
  /// @return True if update occurred.
  function updateABS(
    ActiveBridgeSet storage _abs,
    uint16 _currentSlot,
    uint16 _lastSlot,
    bool _overflow) private returns (bool updated)
  {
    // If there are more than `ACTIVITY_LENGTH` slots empty => remove entirely the ABS
    if (_overflow) {
      flushABS(_abs, _lastSlot, _lastSlot);
    // If ABS are not up to date => fill previous activity slots with empty activities
    } else if (_currentSlot != _lastSlot) {
      flushABS(_abs, _currentSlot, _lastSlot);
    } else {
      return false;
    }

    return true;
  }

  /// @dev Flushes the provided ABS record between lastSlot and currentSlot.
  /// @param _abs The Active Bridge Set to be flushed.
  /// @param _currentSlot The current slot.
  function flushABS(ActiveBridgeSet storage _abs, uint16 _currentSlot, uint16 _lastSlot) private {
    // For each slot elapsed, remove identities and update `nextActiveIdentities` count
    for (uint16 slot = (_lastSlot + 1) % ACTIVITY_LENGTH ; slot != _currentSlot ; slot = (slot + 1) % ACTIVITY_LENGTH) {
      flushSlot(_abs, slot);
    }
    // Update current activity slot
    flushSlot(_abs, _currentSlot);
    _abs.activeIdentities = _abs.nextActiveIdentities;
  }

  /// @dev Flushes a slot of the provided ABS.
  /// @param _abs The Active Bridge Set to be flushed.
  /// @param _slot The slot to be flushed.
  function flushSlot(ActiveBridgeSet storage _abs, uint16 _slot) private {
    // For a given slot, go through all identities to flush them
    for (uint16 id = 0; id < _abs.epochIdentities[_slot].length; id++) {
      flushIdentity(_abs, _abs.epochIdentities[_slot][id]);
    }
    delete _abs.epochIdentities[_slot];
  }

  /// @dev Decrements the appearance counter of an identity from the provided ABS. If the counter reaches 0, the identity is flushed.
  /// @param _abs The Active Bridge Set to be flushed.
  /// @param _address The address to be flushed.
  function flushIdentity(ActiveBridgeSet storage _abs, address _address) private {
    // Decrement the count of an identity, and if it reaches 0, delete it and update `nextActiveIdentities`count
    _abs.identityCount[_address]--;
    if (_abs.identityCount[_address] == 0) {
      delete _abs.identityCount[_address];
      _abs.nextActiveIdentities--;
    }
  }
}