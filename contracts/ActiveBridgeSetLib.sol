pragma solidity ^0.5.0;


/**
 * @title Active Bridge Set (ABS) library
 * @notice TODO
 */
library ActiveBridgeSetLib {

  // Number of Ethereum blocks during which activity can be pushed
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

  function getSlots(ActiveBridgeSet storage _abs, uint256 _blockNumber) private view returns (uint16, uint16, bool) {
    // Get current activity slot number
    uint16 currentSlot = uint16((_blockNumber / CLAIM_BLOCK_PERIOD) % ACTIVITY_LENGTH);
    // Get last actitivy slot number
    uint16 lastSlot = uint16((_abs.lastBlockNumber / CLAIM_BLOCK_PERIOD) % ACTIVITY_LENGTH);
    // Check if there was an activity slot overflow
    bool overflow = (_blockNumber - _abs.lastBlockNumber) >= CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH;

    return (currentSlot, lastSlot, overflow);
  }

  function updateABS(
    ActiveBridgeSet storage _abs,
    uint16 currentSlot,
    uint16 lastSlot,
    bool overflow) private returns (bool updated)
  {
    // If there are more than `ACTIVITY_LENGTH` slots empty => remove entirely the ABS
    if (overflow) {
      flushABS(_abs, lastSlot, lastSlot);
    // If ABS are not up to date => fill previous activity slots with empty activities
    } else if (currentSlot != lastSlot) {
      flushABS(_abs, currentSlot, lastSlot);
    } else {
      return false;
    }

    return true;
  }

  function flushABS(ActiveBridgeSet storage _abs, uint16 _currentSlot, uint16 _lastSlot) private {
    // For each slot elapsed, remove identities and update `nextActiveIdentities` count
    for (uint16 slot = (_lastSlot + 1) % ACTIVITY_LENGTH ; slot != _currentSlot ; slot = (slot + 1) % ACTIVITY_LENGTH) {
      flushSlot(_abs, slot);
    }
    // Update current activity slot
    flushSlot(_abs, _currentSlot);
    _abs.activeIdentities = _abs.nextActiveIdentities;
  }

  function flushSlot(ActiveBridgeSet storage _abs, uint16 slot) private {
    // For a given slot, go through all identities to flush them
    for (uint16 id = 0; id < _abs.epochIdentities[slot].length; id++) {
      flushIdentity(_abs, _abs.epochIdentities[slot][id]);
    }
    delete _abs.epochIdentities[slot];
  }

  function flushIdentity(ActiveBridgeSet storage _abs, address _id) private {
    // Decrement the count of an identity, and if it reaches 0, delete it and update `nextActiveIdentities`count
    _abs.identityCount[_id]--;
    if (_abs.identityCount[_id] == 0) {
      delete _abs.identityCount[_id];
      _abs.nextActiveIdentities--;
    }
  }
}