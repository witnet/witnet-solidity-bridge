// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "../interfaces/V2/IWitnetBlocks.sol";
import "../interfaces/V2/IWitnetBytecodes.sol";
import "../interfaces/V2/IWitnetDecoder.sol";
import "../interfaces/V2/IWitnetRequests.sol";
import "../interfaces/V2/IWitnetRequestsAdmin.sol";
import "../patterns/Payable.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoardV2Data
  is
      ERC165, 
      Payable,
      IWitnetRequestsAdmin
{
    using Strings for address;
    using Strings for uint256;

    bytes32 internal constant _WITNET_REQUEST_BOARD_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data.v2") */
        0xfeed002ff8a708dcba69bac2a8e829fd61fee551b9e9fc0317707d989cb0fe53;

    struct Board {
        address base;
        address owner;
        address pendingOwner;

        IWitnetBlocks blocks;
        IWitnetBytecodes bytecodes;
        IWitnetDecoder decoder;

        IWitnetRequests.Stats serviceStats;
        bytes4 serviceTag;

        mapping (bytes32 => WitnetV2.DrPost) posts;
    }

    constructor() {
        __board().owner = msg.sender;
    }

    /// Asserts the given query is currently in the given status.
    modifier drPostInStatus(bytes32 _drHash, WitnetV2.DrPostStatus _requiredStatus) {
      WitnetV2.DrPostStatus _currentStatus = _getDrPostStatus(_drHash);
      if (_currentStatus != _requiredStatus) {
          revert IWitnetRequests.DrPostNotInStatus(
              _drHash,
              _currentStatus,
              _requiredStatus
          );
      }
      _;
    }

    /// Asserts the given query was previously posted and that it was not yet deleted.
    modifier drPostNotDeleted(bytes32 _drHash) {
        WitnetV2.DrPostStatus _currentStatus = __drPost(_drHash).status;
        if (uint(_currentStatus) <= uint(WitnetV2.DrPostStatus.Deleted)) {
          revert IWitnetRequests.DrPostBadMood(_drHash, _currentStatus);
        } 
        _;
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Returns storage pointer to contents of 'Board' struct.
    function __board()
      internal pure
      returns (Board storage _ptr)
    {
        assembly {
            _ptr.slot := _WITNET_REQUEST_BOARD_DATA_SLOTHASH
        }
    }

    function _canDrPostBeDeletedFrom(bytes32 _drHash, address _from)
        internal view
        virtual
        returns (bool _itCanBeDeleted)
    {
        WitnetV2.DrPostStatus _currentStatus = _getDrPostStatus(_drHash);
        if (_from == __drPostRequest(_drHash).requester) {
            _itCanBeDeleted = (
                _currentStatus == WitnetV2.DrPostStatus.Finalized
                    || _currentStatus == WitnetV2.DrPostStatus.Expired
            );
        }
    }

    function __deleteDrPost(bytes32 _drHash)
        internal
        virtual 
    {
        WitnetV2.DrPostRequest storage __request = __drPostRequest(_drHash);
        uint _value = __request.weiReward;
        address _to = __request.requester;
        delete __board().posts[_drHash];
        if (address(this).balance < _value) {
            revert WitnetV2.InsufficientBalance(address(this).balance, _value);
        }
        _safeTransferTo(payable(_to), _value);
    }

    function __deleteDrPostRequest(bytes32 _drHash)
        internal
        virtual
    {
        delete __drPost(_drHash).request;
    }

    function _getDrPostBlock(bytes32 _drHash)
      internal view
      virtual
      returns (uint256)
    {
        return __drPost(_drHash).block;
    }

    /// Gets current status of given query.
    function _getDrPostStatus(bytes32 _drHash)
      internal view
      virtual
      returns (WitnetV2.DrPostStatus _temporaryStatus)
    {
      uint256 _drPostBlock = _getDrPostBlock(_drHash);
      _temporaryStatus = __drPost(_drHash).status;
      if (
        _temporaryStatus == WitnetV2.DrPostStatus.Reported
          || _temporaryStatus == WitnetV2.DrPostStatus.Disputed
          || _temporaryStatus == WitnetV2.DrPostStatus.Accepted
      ) {
        if (block.number > _drPostBlock + 256 /* TODO: __drPostExpirationBlocks */) {
          _temporaryStatus = WitnetV2.DrPostStatus.Expired;
        }
      }
    }

    // /// Gets from of a given query.
    function __drPost(bytes32 _drHash)
      internal view
      returns (WitnetV2.DrPost storage)
    {
      return __board().posts[_drHash];
    }

    /// Gets the WitnetV2.DrPostRequest part of a given post.
    function __drPostRequest(bytes32 _drHash)
      internal view
      returns (WitnetV2.DrPostRequest storage)
    {
        return __board().posts[_drHash].request;
    }

    /// Gets the Witnet.Result part of a given post.
    function __drPostResponse(bytes32 _drHash)
      internal view
      returns (WitnetV2.DrPostResponse storage)
    {
        return __board().posts[_drHash].response;
    }

    function __setServiceTag()
        internal
        virtual
        returns (bytes4 _serviceTag)
    {
        _serviceTag = bytes4(keccak256(abi.encodePacked(
            "evm::",
            block.chainid.toString(),
            "::",
            address(this).toHexString()
        )));
        __board().serviceTag = _serviceTag;
    }

}