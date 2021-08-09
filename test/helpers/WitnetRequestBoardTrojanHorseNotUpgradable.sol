// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../../contracts/utils/Initializable.sol";
import "../../contracts/utils/Proxiable.sol";

/**
 * @title Witnet Requests Board Trojan Horse: Proxiable but not-Upgradable
 * @notice Contract to test proxy upgrade assertions.
 * @dev Upgrading an existing WitnetRequestBoard implementation with an instance of 
 * this kind (i.e. Proxiable but not-Upgradable), should not be permitted by the WitnetProxy.
 * The contract has been created for testing purposes.
 * @author Witnet Foundation
 */
contract WitnetRequestBoardTrojanHorseNotUpgradable is Initializable, Proxiable {
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

  function isUpgradableFrom(address) external pure returns (bool) {
    return true;
  }

  function proxiableUUID() external pure override returns (bytes32) {
    return (
      /* keccak256("io.witnet.proxiable.board") */
  0x9969c6aff411c5e5f0807500693e8f819ce88529615cfa6cab569b24788a1018
    );
  }

  /* On purpose: isUpgradable(bool) not to be implemented */
}
