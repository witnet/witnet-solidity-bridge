// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title WitnetFeeds data model.
/// @author The Witnet Foundation.
abstract contract WitnetFeedsData {
    
    bytes32 private constant _WITNET_FEEDS_DATA_SLOTHASH =
        /* keccak256("io.witnet.feeds.data") */
        0xe36ea87c48340f2c23c9e1c9f72f5c5165184e75683a4d2a19148e5964c1d1ff;

    struct Storage {
        bytes32 defaultSlaHash;
        bytes4[] ids;
        mapping (bytes4 => Record) records;
    }

    struct Record {
        string  caption;
        uint8   decimals;
        uint256 index;
        uint256 lastValidQueryId;
        uint256 latestUpdateQueryId;
        bytes32 radHash;
        address solver;
    }

    // ================================================================================================
    // --- Internal functions -------------------------------------------------------------------------
    
    function __storage()
      internal pure
      returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WITNET_FEEDS_DATA_SLOTHASH
        }
    }

    function __records_(bytes4 feedId) internal view returns (Record storage) {
        return __storage().records[feedId];
    }
}