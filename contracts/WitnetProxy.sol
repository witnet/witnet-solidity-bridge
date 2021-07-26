// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./utils/Upgradable.sol";

contract WitnetProxy {
  Upgradable public delegate;

  /// @dev Constructor with no params as to ease eventual support of Singleton pattern (i.e. ERC-2470)
  constructor () {}

  /// @dev WitnetProxies will never accept direct transfer of ETHs.
  receive() external payable {
    revert("WitnetProxy: no ETH accepted");
  }

  /// @dev Payable fallback accepts delegating calls to payable functions.  
  fallback() external payable { /* solhint-disable no-complex-fallback */
    address _delegate = address(delegate);

    assembly { /* solhint-disable avoid-low-level-calls */
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

  /// @dev Upgrades the `delegate` address.
  /// @param _newDelegate New implementation address.
  /// @param _initData Raw data with which new implementation will be initialized.
  /// @return Returns whether new implementation would be further upgradable, or not.
  function upgrade(address _newDelegate, bytes memory _initData)
    public returns (bool)
  {
    // New delegate cannot be null:
    require(_newDelegate != address(0), "WitnetProxy: null delegate");

    if (address(delegate) != address(0)) {
      // New delegate address must differ from current one:
      require(_newDelegate != address(delegate), "WitnetProxy: nothing to upgrade");

      // Assert whether current implementation is intrinsically upgradable:
      try delegate.isUpgradable() returns (bool _isUpgradable) {
        require(_isUpgradable, "WitnetProxy: not upgradable");
      } catch {
        revert("WitnetProxy: unable to check upgradability");
      }

      // Assert whether current implementation allows `msg.sender` to upgrade the proxy:
      (bool _wasCalled, bytes memory _result) = address(delegate).delegatecall(
        abi.encodeWithSignature(
          "isUpgradableFrom(address)",
          msg.sender
        )
      );
      require(_wasCalled, "WitnetProxy: not compliant");
      require(abi.decode(_result, (bool)), "WitnetProxy: not authorized");
    }

    // Initialize new implementation within proxy-context storage:
    (bool _wasInitialized,) = _newDelegate.delegatecall(
      abi.encodeWithSignature(
        "initialize(bytes)",
        _initData
      )
    );
    require(_wasInitialized, "WitnetProxy: unable to initialize");

    // If all checks and initialization pass, update implementation address:
    delegate = Upgradable(_newDelegate);

    // Asserts new delegate complies w/ minimal implementation of Upgradable interface:
    try delegate.isUpgradable() returns (bool _isUpgradable) {
      return _isUpgradable;
    }
    catch {
      revert ("WitnetProxy: not compliant");
    }
  }
}
