// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoardData {  

    bytes32 internal constant _WITNET_REQUEST_BOARD_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct WitnetBoardState {
        address base;
        address owner;    
        uint256 nonce;
        mapping (uint => Witnet.Query) queries;
    }

    constructor() {
        __storage().owner = msg.sender;
    }

    /// Asserts the given query is currently in the given status.
    modifier inStatus(uint256 _queryId, Witnet.QueryStatus _status) {
      require(
          _statusOf(_queryId) == _status,
          _statusOfRevertMessage(_status)
      ); _;
    }

    /// Asserts the given query was previously posted and that it was not yet deleted.
    modifier notDeleted(uint256 _queryId) {
        require(
            _queryId > 0 && _queryId <= __storage().nonce, 
            "WitnetRequestBoard: not yet posted"
        );
        require(
            __seekQuery(_queryId).from  != address(0), 
            "WitnetRequestBoard: deleted"
        ); _;
    }

    /// Asserts the caller actually posted the referred query.
    modifier onlyRequester(uint256 _queryId) {
        require(
            msg.sender == __seekQuery(_queryId).from, 
            "WitnetRequestBoardBase: not the requester"
        ); _;
    }

    /// Asserts the given query was actually posted before calling this method.
    modifier wasPosted(uint256 _queryId) {
        require(
            _queryId > 0 && _queryId <= __storage().nonce, 
            "WitnetRequestBoard: not yet posted"
        ); _;
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Gets query storage by query id.
    function __seekQuery(uint256 _queryId) internal view returns (Witnet.Query storage) {
      return __storage().queries[_queryId];
    }

    /// Gets the Witnet.Request part of a given query.
    function __seekQueryRequest(uint256 _queryId)
      internal view
      returns (Witnet.Request storage)
    {
        return __storage().queries[_queryId].request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function __seekQueryResponse(uint256 _queryId)
      internal view
      returns (Witnet.Response storage)
    {
        return __storage().queries[_queryId].response;
    }

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function __storage()
      internal pure
      returns (WitnetBoardState storage _ptr)
    {
        assembly {
            _ptr.slot := _WITNET_REQUEST_BOARD_DATA_SLOTHASH
        }
    }

    /// Gets current status of given query.
    function _statusOf(uint256 _queryId)
      internal view
      returns (Witnet.QueryStatus)
    {
      Witnet.Query storage __query = __storage().queries[_queryId];
      if (__query.response.tallyHash != bytes32(0)) {
        if (__query.response.timestamp != 0) {  
          if (block.number >= Witnet.unpackEvmFinalityBlock(__query.response.fromFinality)) {
            return Witnet.QueryStatus.Finalized;
          } else {
            return Witnet.QueryStatus.Reported;
          }
        } else {
          return Witnet.QueryStatus.Undeliverable;
        }
      } else if (__query.request.fromCallbackGas != bytes32(0)) {
        return Witnet.QueryStatus.Posted;
      } else {
        return Witnet.QueryStatus.Unknown;
      }
    }

    function _statusOfRevertMessage(Witnet.QueryStatus _status)
      internal pure
      returns (string memory)
    {
      if (_status == Witnet.QueryStatus.Posted) {
        return "WitnetRequestBoard: not in Posted status";
      } else if (_status == Witnet.QueryStatus.Reported) {
        return "WitnetRequestBoard: not in Reported status";
      } else if (_status == Witnet.QueryStatus.Finalized) {
        return "WitnetRequestBoard: not in Finalized status";
      } else if (_status == Witnet.QueryStatus.Undeliverable) {
        return "WitnetRequestBoard: not in Undeliverable status";
      } else {
        return "WitnetRequestBoard: bad mood";
      }
    }
}
