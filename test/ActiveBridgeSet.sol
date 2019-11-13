pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "../contracts/ActiveBridgeSet.sol";


contract TestABS {

  using ActiveBridgeSetLib for ActiveBridgeSetLib.ActiveBridgeSet;

  uint8 constant CLAIM_BLOCK_PERIOD = 8;
  uint16 constant ACTIVITY_LENGTH = 100;

  address[] addresses = [address(0x01), address(0x02), address(0x03), address(0x04)];

  ActiveBridgeSetLib.ActiveBridgeSet buf;

  function beforeEach() public {
    buf.lastBlockNumber = 0;
    buf.updateActivity(CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    buf.lastBlockNumber = 0;
  }

  function testGetABSEmpty() public {
    verifyABSStatus(0, 0, 0);
  }

  function testPushActivityNextEpoch() public {
    buf.pushActivity(msg.sender, 0);
    verifyABSStatus(0, 1, 0);

    buf.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
  }

  function testPushActivityTwice() public {
    buf.pushActivity(msg.sender, 0);
    verifyABSStatus(0, 1, 0);
    verifyIdentityCount(msg.sender, 1);

    buf.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(msg.sender, 2);

    buf.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(msg.sender, 2);

    buf.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD * 2);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD * 2);
    verifyIdentityCount(msg.sender, 3);
  }

  function testPushActivityOverflow() public {
    buf.pushActivity(msg.sender, 0);
    verifyABSStatus(0, 1, 0);
    verifyIdentityCount(msg.sender, 1);

    buf.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(msg.sender, 2);

    buf.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD*(ACTIVITY_LENGTH + 1));
    verifyABSStatus(0, 1, CLAIM_BLOCK_PERIOD*(ACTIVITY_LENGTH + 1));
    verifyIdentityCount(msg.sender, 1);
  }

  function testPushActivityMultipleIdentities() public {
    buf.pushActivity(addresses[0], 0);
    buf.pushActivity(addresses[1], 0);
    verifyABSStatus(0, 2, 0);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 1);

    buf.pushActivity(addresses[2], CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 3, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 1);
    verifyIdentityCount(addresses[2], 1);

    buf.pushActivity(addresses[1], CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 3, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 2);
    verifyIdentityCount(addresses[2], 1);

    buf.pushActivity(addresses[3], CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 4, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 2);
    verifyIdentityCount(addresses[2], 1);
    verifyIdentityCount(addresses[3], 1);

    buf.pushActivity(addresses[3], CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    verifyABSStatus(3, 3, CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    verifyIdentityCount(addresses[0], 0);
    verifyIdentityCount(addresses[1], 1);
    verifyIdentityCount(addresses[2], 1);
    verifyIdentityCount(addresses[3], 2);
  }

  function testUpdateActivity() public {
    buf.pushActivity(addresses[0], 0);
    verifyABSStatus(0, 1, 0);

    buf.pushActivity(addresses[1], 0);
    verifyABSStatus(0, 2, 0);

    buf.updateActivity(CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 2, CLAIM_BLOCK_PERIOD);

    buf.updateActivity(CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    verifyABSStatus(0, 0, CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
  }

  function verifyABSStatus(uint32 _activeIdentities, uint32 _nextActiveIdentities, uint256 _lastBlockNumber) internal {
    Assert.equal(uint(buf.activeIdentities), uint(_activeIdentities), "ABS active identities do not match");
    Assert.equal(uint(buf.nextActiveIdentities), uint(_nextActiveIdentities), "ABS next active identities do not match");
    Assert.equal(uint(buf.lastBlockNumber), uint(_lastBlockNumber), "ABS block number do not match");
  }

  function verifyIdentityCount(address _address, uint16 _count) internal {
    Assert.equal(uint(buf.identityCount[_address]), uint(_count), "ABS identity count do not match");
  }

}
