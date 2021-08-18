// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/WitnetData.sol";

/// @title Witnet Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetBoardData {  

  struct WitnetBoardState {
    address base;
    address owner;    
    uint256 numRecords;
    mapping (uint => WitnetBoardDataRequest) requests;
  }

  struct WitnetBoardDataRequest {
    WitnetData.Query query;
    bytes result;
  }

  constructor() {
    _state().owner = msg.sender;
  }

  modifier notDestroyed(uint256 _id) {
    require(_id > 0 && _id <= _state().numRecords, "WitnetBoardData: not yet posted");
    require(_getRequestQuery(_id).requestor != address(0), "WitnetBoardData: destroyed");
    _;
  }

  modifier onlyOwner {
    require(msg.sender == _state().owner, "WitnetBoardData: only owner");
    _;    
  }

  modifier resultNotYetReported(uint256 _id) {
    require(_getRequestQuery(_id).txhash == 0, "WitnetBoardData: already solved");
    _;
  }

  modifier wasPosted(uint256 _id) {
    require(_id > 0 && _id <= _state().numRecords, "WitnetBoardData: not yet posted");
    _;
  }

  /// Gets admin/owner address.
  function owner() public view returns (address) {
    return _state().owner;
  }

  /// Returns storage pointer to contents of 'WitnetBoardState' struct.
  function _state()
    internal pure
    returns (WitnetBoardState storage _ptr)
  {
    assembly {
      _ptr.slot := _WITNET_BOARD_DATA_SLOTHASH
    }
  }

  /// Gets WitnetData.Query struct contents of given request.
  function _getRequestQuery(uint256 _requestId)
    internal view
    returns (WitnetData.Query storage)
  {
    return _state().requests[_requestId].query;
  }
  
  bytes32 internal constant _WITNET_BOARD_DATA_SLOTHASH =
    /* keccak256("io.witnet.board.data") */
    0x641d5bbf2c42118a382e660df7903a98dce7b5bb834d3ba9beae1890b2a72054;
}
