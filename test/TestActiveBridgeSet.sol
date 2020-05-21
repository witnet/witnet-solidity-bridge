// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "truffle/Assert.sol";
import "../contracts/ActiveBridgeSetLib.sol";


contract TestActiveBridgeSet {

  using ActiveBridgeSetLib for ActiveBridgeSetLib.ActiveBridgeSet;

  uint8 constant internal CLAIM_BLOCK_PERIOD = 8;
  uint16 constant internal ACTIVITY_LENGTH = 100;

  address[] internal addresses = [
    address(0x01),
    address(0x02),
    address(0x03),
    address(0x04)
  ];

  ActiveBridgeSetLib.ActiveBridgeSet internal abs;
  ActiveBridgeSetLib.ActiveBridgeSet internal fakeAbs;

  function beforeEach() external {
    abs.lastBlockNumber = 0;
    abs.updateActivity(CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    abs.lastBlockNumber = 0;
  }

  function testGetABSEmpty() external {
    verifyABSStatus(0, 0, 0);
  }

  function testPushActivityNextEpoch() external {
    abs.pushActivity(msg.sender, 0);
    verifyABSStatus(0, 1, 0);

    abs.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
  }

  function testPushActivityTwice() external {
    abs.pushActivity(msg.sender, 0);
    verifyABSStatus(0, 1, 0);
    verifyIdentityCount(msg.sender, 1);

    abs.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(msg.sender, 2);

    abs.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(msg.sender, 2);

    abs.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD * 2);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD * 2);
    verifyIdentityCount(msg.sender, 3);
  }

  function testPushActivityOverflow() external {
    abs.pushActivity(msg.sender, 0);
    verifyABSStatus(0, 1, 0);
    verifyIdentityCount(msg.sender, 1);

    abs.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD);
    verifyABSStatus(1, 1, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(msg.sender, 2);

    abs.pushActivity(msg.sender, CLAIM_BLOCK_PERIOD*(ACTIVITY_LENGTH + 1));
    verifyABSStatus(0, 1, CLAIM_BLOCK_PERIOD*(ACTIVITY_LENGTH + 1));
    verifyIdentityCount(msg.sender, 1);
  }

  function testPushActivityMultipleIdentities() external {
    abs.pushActivity(addresses[0], 0);
    abs.pushActivity(addresses[1], 0);
    verifyABSStatus(0, 2, 0);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 1);

    abs.pushActivity(addresses[2], CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 3, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 1);
    verifyIdentityCount(addresses[2], 1);

    abs.pushActivity(addresses[1], CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 3, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 2);
    verifyIdentityCount(addresses[2], 1);

    abs.pushActivity(addresses[3], CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 4, CLAIM_BLOCK_PERIOD);
    verifyIdentityCount(addresses[0], 1);
    verifyIdentityCount(addresses[1], 2);
    verifyIdentityCount(addresses[2], 1);
    verifyIdentityCount(addresses[3], 1);

    abs.pushActivity(addresses[3], CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    verifyABSStatus(3, 3, CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    verifyIdentityCount(addresses[0], 0);
    verifyIdentityCount(addresses[1], 1);
    verifyIdentityCount(addresses[2], 1);
    verifyIdentityCount(addresses[3], 2);
  }

  function testUpdateActivity() external {
    abs.pushActivity(addresses[0], 0);
    verifyABSStatus(0, 1, 0);

    abs.pushActivity(addresses[1], 0);
    verifyABSStatus(0, 2, 0);

    abs.updateActivity(CLAIM_BLOCK_PERIOD);
    verifyABSStatus(2, 2, CLAIM_BLOCK_PERIOD);

    abs.updateActivity(CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
    verifyABSStatus(0, 0, CLAIM_BLOCK_PERIOD * ACTIVITY_LENGTH);
  }

  function verifyABSStatus(uint32 _activeIdentities, uint32 _nextActiveIdentities, uint256 _lastBlockNumber) internal {
    Assert.equal(uint(abs.activeIdentities), uint(_activeIdentities), "ABS active identities does not match");
    Assert.equal(uint(abs.nextActiveIdentities), uint(_nextActiveIdentities), "ABS next active identities do not match");
    Assert.equal(uint(abs.lastBlockNumber), uint(_lastBlockNumber), "ABS block number does not match");
  }

  function verifyIdentityCount(address _address, uint16 _count) internal {
    Assert.equal(uint(abs.identityCount[_address]), uint(_count), "ABS identity count does not match");
  }

  function testNotValidUpdateBlockNumber() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    fakeAbs.lastBlockNumber = 1;
    TestActiveBridgeSet(address(throwProxy)).errorUpdateABS(0);
    (r, error) = throwProxy.execute.gas(100000)();
    Assert.isFalse(r, "The provided block is older than the last updated block");
  }

  function testNotValidPushBlockNumber() external {
    ThrowProxy throwProxy = new ThrowProxy(address(this));
    bool r;
    bytes memory error;
    fakeAbs.lastBlockNumber = 1;
    TestActiveBridgeSet(address(throwProxy)).errorPushABS(address(0), 0);
    (r, error) = throwProxy.execute.gas(100000)();
    Assert.isFalse(r, "The provided block is older than the last updated block");
  }

  function errorUpdateABS(uint256 _blockNumber) public {
    fakeAbs.updateActivity(_blockNumber);
  }

  function errorPushABS(address a, uint256 _blockNumber) public {
    fakeAbs.pushActivity(a, _blockNumber);
  }

}


// Proxy contract for testing throws
contract ThrowProxy {
  address public target;
  bytes data;

  constructor (address _target) public {
    target = _target;
  }

  fallback () external {
    data = msg.data;
  }

  function execute() public returns (bool, bytes memory) {
    return target.call(data);
  }
}
