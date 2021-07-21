// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetBoardData.sol";

/**
 * @title Witnet Access Control Lists storage layout, for centralized request boards.
 * @author Witnet Foundation
 */
abstract contract WitnetBoardDataACLs is WitnetBoardData {  
  struct SWitnetBoardACLs {
    mapping (address => bool) isReporter_;
  }

  constructor() {
    __acls().isReporter_[msg.sender] = true;
  }

  modifier onlyReporters {
    require(__acls().isReporter_[msg.sender], "WitnetBoardDataACLs: unauthorized reporter");
    _;
  }  

  function __acls() internal pure returns (SWitnetBoardACLs storage _struct) {
    assembly {
      _struct.slot := WITNET_BOARD_ACLS_SLOTHASH
    }
  }
  
  bytes32 internal constant WITNET_BOARD_ACLS_SLOTHASH = "WitnetBoard.ACLs";
}
