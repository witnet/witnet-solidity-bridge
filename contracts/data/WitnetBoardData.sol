// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

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
    }

    constructor() {
        _state().owner = msg.sender;
    }

    /// Asserts the given query is currently in the given status.
    modifier inStatus(uint256 _queryId, Witnet.QueryStatus _status) {
      require(
          _getQueryStatus(_queryId) == _status,
          _getQueryStatusRevertMessage(_status)
        );
      _;
    }

    /// Asserts the given query was previously posted and that it was not yet deleted.
    modifier notDeleted(uint256 _queryId) {
        require(_queryId > 0 && _queryId <= _state().numQueries, "WitnetBoardData: not yet posted");
        require(_getRequestData(_queryId).requester != address(0), "WitnetBoardData: deleted");
        _;
    }

    /// Asserts caller corresponds to the current owner. 
    modifier onlyOwner {
        require(msg.sender == _state().owner, "WitnetBoardData: only owner");
        _;    
    }

    /// Asserts the give query was actually posted before calling this method.
    modifier wasPosted(uint256 _queryId) {
        require(_queryId > 0 && _queryId <= _state().numQueries, "WitnetBoardData: not yet posted");
        _;
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Gets current status of given query.
    function _getQueryStatus(uint256 _queryId)
      internal view
      returns (Witnet.QueryStatus)
    {
      if (_queryId == 0 || _queryId > _state().numQueries)
        return Witnet.QueryStatus.Unknown;
      else {
        Witnet.Query storage _query = _state().queries[_queryId];
        if (_query.request.requester == address(0))
          return Witnet.QueryStatus.Deleted;
        else if (_query.response.drTxHash != 0) 
          return Witnet.QueryStatus.Reported;
        else
          return Witnet.QueryStatus.Posted;
      }
    }

    function _getQueryStatusRevertMessage(Witnet.QueryStatus _status)
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

    /// Gets the Witnet.Request part of a given query.
    function _getRequestData(uint256 _queryId)
      internal view
      returns (Witnet.Request storage)
    {
        return _state().queries[_queryId].request;
    }

    /// Gets the Witnet.Result part of a given query.
    function _getResponseData(uint256 _queryId)
      internal view
      returns (Witnet.Response storage)
    {
        return _state().queries[_queryId].response;
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

}
