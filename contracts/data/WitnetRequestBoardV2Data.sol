// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/WitnetV2.sol";
import "../interfaces/V2/IWitnetBlocks.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoardV2Data {  

    bytes32 internal constant _WITNET_BOARD_DATA_SLOTHASH =
      /* keccak256("io.witnet.boards.data.v2") */
      0xfeed002ff8a708dcba69bac2a8e829fd61fee551b9e9fc0317707d989cb0fe53;

    struct Storage {
      uint256 nonce;
      mapping (address => Escrow) escrows;
      mapping (bytes32 => WitnetV2.Query) queries;
    }

    struct Escrow {
      uint256 atStake;
      uint256 balance;
    }

    /// Asserts the given query was previously posted but not yet deleted.
    modifier queryExists(bytes32 queryHash) {
      require(__query_(queryHash).from != address(0), "WitnetRequestBoardV2Data: empty query");
      _;
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Gets query storage by query id.
    function __query_(bytes32 queryHash) internal view returns (WitnetV2.Query storage) {
      return __storage().queries[queryHash];
    }

    /// Gets the Witnet.Request part of a given query.
    function __request_(bytes32 queryHash) internal view returns (WitnetV2.QueryRequest storage) {
        return __query_(queryHash).request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function __report_(bytes32 queryHash) internal view returns (WitnetV2.QueryReport storage) {
        return __query_(queryHash).report;
    }

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function __storage() internal pure returns (Storage storage _ptr) {
        assembly {
            _ptr.slot := _WITNET_BOARD_DATA_SLOTHASH
        }
    }

    /// Gets current status of given query.
    function _statusOf(bytes32 queryHash, IWitnetBlocks blocks)
      internal view
      returns (WitnetV2.QueryStatus)
    {
      WitnetV2.Query storage __query = __query_(queryHash);
      if (__query.reporter != address(0) || __query.disputes.length > 0) {
        if (blocks.getLastBeaconIndex() >= __query.epoch) {
          return WitnetV2.QueryStatus.Finalized;
        } else {
          if (__query.disputes.length > 0) {
            return WitnetV2.QueryStatus.Disputed;
          } else {
            return WitnetV2.QueryStatus.Reported;
          }
        }
      } else if (__query.from != address(0)) {
        return WitnetV2.checkQueryPostStatus(
          __query.epoch, 
          blocks.getCurrentBeaconIndex()
        );
      } else {
        return WitnetV2.QueryStatus.Void;
      }
    }

    function _statusOfRevertMessage(WitnetV2.QueryStatus queryStatus)
      internal pure
      returns (string memory)
    {
      string memory _reason;
      if (queryStatus == WitnetV2.QueryStatus.Posted) {
        _reason = "Posted";
      } else if (queryStatus == WitnetV2.QueryStatus.Reported) {
        _reason = "Reported";
      } else if (queryStatus == WitnetV2.QueryStatus.Disputed) {
        _reason = "Disputed";
      } else if (queryStatus == WitnetV2.QueryStatus.Expired) {
        _reason = "Expired";
      } else if (queryStatus == WitnetV2.QueryStatus.Finalized) {
        _reason = "Finalized";
      } else {
        _reason = "expected";
      }
      return string(abi.encodePacked(
        "WitnetRequestBoardV2Data: not in ", 
        _reason,
        " status"
      ));
    }
}
