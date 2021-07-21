// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-complex-fallback */

import "./utils/Upgradable.sol";

contract WitnetProxy {
  Upgradable public delegate;

  constructor () {}

  receive() external payable {
    revert("WitnetProxy: no ETH accepted");
  }

  fallback() external payable {
    address _delegate = address(delegate);
    assembly {
      // Gas optimized delegate call to 'delegate' contract.
      // Note: `msg.data`, `msg.sender` and `msg.value` will be passed over 
      //       to actual implementation of `msg.sig` within `delegate` contract.
      let ptr := mload(0x40)
      calldatacopy(ptr, 0, calldatasize())
      let result := delegatecall(gas(), _delegate, ptr, calldatasize(), 0, 0)
      let size := returndatasize()
      returndatacopy(ptr, 0, size)
      switch result
        case 0  { 
          // pass back revert message:
          revert(ptr, size) 
        }
        default {
          // pass back same data as returned by 'delegate' contract:
          return(ptr, size) 
        }
    }
  }

  function upgrade(address _newDelegate, bytes memory _initData) public {
    require(_newDelegate != address(0), "WitnetProxy: null delegate");
    if (address(delegate) != address(0)) {
      require(
        _newDelegate != address(delegate),
        "WitnetProxy: nothing to upgrade"
      );
      require(
        delegate.isUpgradable(),
        "WitnetProxy: not upgradable"
      );
      (bool _wasCalled, bytes memory _result) = address(delegate).delegatecall(
        abi.encodeWithSignature(
          "isUpgradableFrom(address)",
          msg.sender
        )
      );
      require(
        _wasCalled && abi.decode(_result, (bool)),
        "WitnetProxy: not authorized"
      );
    }
    (bool _wasInitialized,) = _newDelegate.delegatecall(
      abi.encodeWithSignature(
        "initialize(bytes)",
        _initData
      )
    );
    require(
      _wasInitialized,
      "WitnetProxy: unable to initialize"
    );
    delegate = Upgradable(_newDelegate);
  }
}
