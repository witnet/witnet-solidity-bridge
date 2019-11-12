pragma solidity ^0.5.0;


/**
 * @title TODO
 * @notice TODO
 */
library ActiveBridgeSetLib {

  uint8 constant CLAIM_BLOCK_PERIOD = 8;
  uint16 constant ACTIVITY_LENGTH = 2000;

  struct ActiveBridgeSet {
    // Mapping of activity slots with appeared identities
    mapping (uint16 => address[]) epochIdentities;
    // Mapping of identities with their appereance count
    mapping (address => uint16) identityCount;
    // Last computed blockNumber
    uint256 lastBlockNumber;
    // Number of identities in Active Bridge Set (consolidated)
    uint32 activeIdentities;
    // Number of identities for the next activity slot (not yet consolidated)
    uint32 nextActiveIdentities;
  }

  function pushActivity(ActiveBridgeSet storage _abs, address _address, uint256 _blockNumber) internal returns (bool success) {

    // Get last actitivy slot number
    uint16 lastSlot = uint16((_abs.lastBlockNumber / CLAIM_BLOCK_PERIOD) % ACTIVITY_LENGTH);

    // Get current activity slot number
    uint16 currentSlot = uint16((_blockNumber / CLAIM_BLOCK_PERIOD) % ACTIVITY_LENGTH);

    // If there are more than 2000 activity slots empty => remove completely the ABS
    if ((_blockNumber - _abs.lastBlockNumber) > CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH) {
      // call updateABS(_abs, lastSlot, lastSlot) to remove everything
      updateABS(_abs, lastSlot, lastSlot);
      _abs.lastBlockNumber = _blockNumber;
    // If we are not up to date => fill previous activity slots with empty activities
    } else if (currentSlot != lastSlot) {
      // TODO: remove lastSlot var?
      updateABS(_abs, currentSlot, lastSlot);
      _abs.lastBlockNumber = _blockNumber;
    } else {
      // If address does not exists in `epochIdentities` with epoch = currentSlot => add identity
      for (uint i; i < _abs.epochIdentities[currentSlot].length; i++) {
        if (_abs.epochIdentities[currentSlot][i] == _address) {
          // Address was already counted as active identity
          return false;
        }
      }
    }

    // Update current activity slot:
    //  1. Add currentSlot to `epochIdentities` with address
    //  2. Increment by 1 address to `identities`
    //  3. Increment by 1 `activeIdentities`
    _abs.epochIdentities[currentSlot].push(_address);
    _abs.identityCount[_address]++;
    _abs.nextActiveIdentities++;

    return true;
  }

  function updateABS(ActiveBridgeSet storage _abs, uint16 _currentSlot, uint16 _lastSlot) internal {
    // for each slot elapsed, remove identities and update the current ABS
    for (uint16 slot = _lastSlot + 1; slot <= _currentSlot ; slot = ((slot + 1) % ACTIVITY_LENGTH)) {
      flushSlot(_abs, slot);
    }
    _abs.activeIdentities = _abs.nextActiveIdentities;
  }

  function flushSlot(ActiveBridgeSet storage _abs, uint16 slot) internal {
    // for a given slot, go through all identities to flush them
    for (uint16 id = 0; id < _abs.epochIdentities[slot].length; id++) {
      flushIdentity(_abs, _abs.epochIdentities[slot][id]);
    }
    delete _abs.epochIdentities[slot];
  }

  function flushIdentity(ActiveBridgeSet storage _abs, address _id) internal {
    // decrement the count of an identity, and if reaches 0, delete it from the mapping
    _abs.identityCount[_id]--;
    if (_abs.identityCount[_id] == 0) {
      delete _abs.identityCount[_id];
      _abs.nextActiveIdentities--;
    }
  }

  function getABS(ActiveBridgeSet storage _abs) internal view returns(uint32) {
    // return the current ABS set
    return _abs.activeIdentities;
  }

}