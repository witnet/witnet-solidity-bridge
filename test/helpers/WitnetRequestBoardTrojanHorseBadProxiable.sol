// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../../contracts/utils/Initializable.sol";
import "../../contracts/utils/Proxiable.sol";

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
  address internal immutable __base;
  bytes32 internal immutable __codehash;
  address internal immutable __owner;

  constructor() {
    address _base = address(this);
    bytes32 _codehash;        
    assembly {
      _codehash := extcodehash(_base)
    }
    __base = _base;
    __codehash = _codehash;   
    __owner = msg.sender;
  }

  modifier onlyOwner {
    if (msg.sender == __owner) {
      _;
    }
  }

  function initialize(bytes calldata) external override onlyOwner {
    emit Initialized(msg.sender, __base, __codehash, "trojan-horse-not-upgradable");
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
