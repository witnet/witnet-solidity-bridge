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
      mapping (address => Escrow) escrows;
      mapping (/* queryHash */ bytes32 => WitnetV2.Query) queries;
      mapping (/* tallyHash */ bytes32 => Suitor) suitors;
    }

    struct Suitor {
      uint256 index;
      bytes32 queryHash;
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
}
