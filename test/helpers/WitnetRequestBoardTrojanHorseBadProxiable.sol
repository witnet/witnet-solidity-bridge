// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/* solhint-disable var-name-mixedcase */

import "../../contracts/patterns/Initializable.sol";
import "../../contracts/patterns/Proxiable.sol";

/**
 * @title Witnet Requests Board Trojan Horse: Proxiable with a bad `proxiableUUID()`.
 * @notice Contract to test proxy upgrade assertions.
 * @dev Upgrading an existing WitnetRequestBoard implementation with an instance of 
 * this kind (i.e. Proxiable and Upgradable) but with a `proxiableUUID()` value different
 * to the one required for WitnetRequestBoards, should not be permitted by the WitnetProxy.
 * The contract has been created for testing purposes.
 * @author Witnet Foundation
 */
contract WitnetRequestBoardTrojanHorseBadProxiable is Initializable, Proxiable {
  address internal immutable _BASE;
  bytes32 internal immutable _CODEHASH;
  address internal immutable _OWNER;

  constructor() {
    address _base = address(this);
    bytes32 _codehash;        
    assembly {
      _codehash := extcodehash(_base)
    }
    _BASE = _base;
    _CODEHASH = _codehash;   
    _OWNER = msg.sender;
  }

  modifier onlyOwner {
    if (msg.sender == _OWNER) {
      _;
    }
  }

  function initialize(bytes calldata) external override {
      // WATCH OUT: any one could reset storage context after 
      // upgrading the WRB to this implementation.
  }

  function isUpgradable() external pure returns (bool) {
    return false;
  }

  function isUpgradableFrom(address) external pure returns (bool) {
    return true;
  }

  function proxiableUUID() external pure override returns (bytes32) {
    return (
      /* On purpose: keccak256("WitnetRequestBoardTrojanHorseBadProxiable") */
      0x4d3080726a91bfa6730c817863d1d6dc232091b814f64e60803244379b522d7d
    );
  }
}
