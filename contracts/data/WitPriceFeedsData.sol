// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title WitFeeds data model.
/// @author The Witnet Foundation.
abstract contract WitPriceFeedsData {
    
    bytes32 private constant _WIT_FEEDS_DATA_SLOTHASH =
        /* keccak256("io.witnet.feeds.data") */
        0xe36ea87c48340f2c23c9e1c9f72f5c5165184e75683a4d2a19148e5964c1d1ff;

    struct Storage {
        bytes32 reserved;
        bytes4[] ids;
        mapping (bytes4 => Record) records;
    }

    struct Record {
        string  caption;
        uint8   decimals;
        uint256 index;
        Witnet.QueryId lastValidQueryId;
        Witnet.QueryId latestUpdateQueryId;
        bytes32 radHash;
        address solver;         // logic contract address for reducing values on routed feeds.
        int256  solverReductor; // as to reduce resulting number of decimals on routed feeds.
        bytes32 solverDepsFlag; // as to store ids of up to 8 depending feeds.
    }

    // ================================================================================================
    // --- Internal functions -------------------------------------------------------------------------
    
    /// @notice Returns storage pointer to where Storage data is located. 
    function __storage()
      internal pure
      returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WIT_FEEDS_DATA_SLOTHASH
        }
    }

    /// @notice Returns storage pointer to where Record for given feedId is located.
    function __records_(bytes4 feedId) internal view returns (Record storage) {
        return __storage().records[feedId];
    }

    /// @notice Returns array of feed ids from which given feed's value depends.
    /// @dev Returns empty array on either unsupported or not-routed feeds.
    /// @dev The maximum number of dependencies is hard-limited to 8, as to limit number
    /// @dev of SSTORE operations (`__storage().records[feedId].solverDepsFlag`), 
    /// @dev no matter the actual number of depending feeds involved.
    function _depsOf(bytes4 feedId) internal view returns (bytes4[] memory _deps) {
        bytes32 _solverDepsFlag = __storage().records[feedId].solverDepsFlag;
        _deps = new bytes4[](8);
        uint _len;
        for (_len = 0; _len < 8; _len ++) {
            _deps[_len] = bytes4(_solverDepsFlag);
            if (_deps[_len] == 0) {
                break;
            } else {
                _solverDepsFlag <<= 32;
            }
        }
        assembly {
            // reset length to actual number of dependencies:
            mstore(_deps, _len)
        }
    }
}