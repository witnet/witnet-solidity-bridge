// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";
import "../interfaces/V2/IWitnetBytecodes.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetBoardData {  

    bytes32 internal constant _WITNET_BOARD_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct WitnetBoardState {
        address base;
        address owner;    
        uint256 numQueries;
        mapping (uint => Witnet.Query) queries;
        IWitnetBytecodes registry;
    }

    constructor() {
        __storage().owner = msg.sender;
    }

    /// Asserts the given query is currently in the given status.
    modifier inStatus(uint256 _queryId, Witnet.QueryStatus _status) {
      require(
          _statusOf(_queryId) == _status,
          _statusOfRevertMessage(_status)
        );
      _;
    }

    /// Asserts the given query was previously posted and that it was not yet deleted.
    modifier notDeleted(uint256 _queryId) {
        require(_queryId > 0 && _queryId <= __storage().numQueries, "WitnetBoardData: not yet posted");
        require(__query(_queryId).from  != address(0), "WitnetBoardData: deleted");
        _;
    }

    /// Asserts the give query was actually posted before calling this method.
    modifier wasPosted(uint256 _queryId) {
        require(_queryId > 0 && _queryId <= __storage().numQueries, "WitnetBoardData: not yet posted");
        _;
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Gets query storage by query id.
    function __query(uint256 _queryId) internal view returns (Witnet.Query storage) {
      return __storage().queries[_queryId];
    }

    /// Gets the Witnet.Request part of a given query.
    function __request(uint256 _queryId)
      internal view
      returns (Witnet.Request storage)
    {
        return __storage().queries[_queryId].request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function __response(uint256 _queryId)
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
            _ptr.slot := _WITNET_BOARD_DATA_SLOTHASH
        }
    }

    /// Gets current status of given query.
    function _statusOf(uint256 _queryId)
      internal view
      returns (Witnet.QueryStatus)
    {
      Witnet.Query storage _query = __storage().queries[_queryId];
      if (_query.response.drTxHash != 0) {
        // Query is in "Reported" status as soon as the hash of the
        // Witnet transaction that solved the query is reported
        // back from a Witnet bridge:
        return Witnet.QueryStatus.Reported;
      }
      else if (_query.from != address(0)) {
        // Otherwise, while address from which the query was posted
        // is kept in storage, the query remains in "Posted" status:
        return Witnet.QueryStatus.Posted;
      }
      else if (_queryId > __storage().numQueries) {
        // Requester's address is removed from storage only if
        // the query gets "Deleted" by its requester.
        return Witnet.QueryStatus.Deleted;
      } else {
        return Witnet.QueryStatus.Unknown;
      }
    }

    function _statusOfRevertMessage(Witnet.QueryStatus _status)
      internal pure
      returns (string memory)
    {
      if (_status == Witnet.QueryStatus.Posted) {
        return "WitnetBoardData: not in Posted status";
      } else if (_status == Witnet.QueryStatus.Reported) {
        return "WitnetBoardData: not in Reported status";
      } else if (_status == Witnet.QueryStatus.Deleted) {
        return "WitnetBoardData: not in Deleted status";
      } else {
        return "WitnetBoardData: bad mood";
      }
    }
}
