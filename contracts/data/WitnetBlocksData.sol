// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/WitnetV2.sol";

/// @title WitnetBlocks data model.
/// @author The Witnet Foundation.
abstract contract WitnetBlocksData {
    
    bytes32 private constant _WITNET_BLOCKS_DATA_SLOTHASH =
        /* keccak256("io.witnet.blocks.data") */
        0x28b1d7e478138a94698f82768889fd6edf6b777bb6815c200552870d3e78ffb5;

    struct Storage {
        WitnetV2.Beacon lastBeacon;
    }

    // ================================================================================================
    // --- Internal functions -------------------------------------------------------------------------
    
    /// @notice Returns storage pointer to where Storage data is located. 
    function __blocks()
      internal pure
      returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WITNET_BLOCKS_DATA_SLOTHASH
        }
    }

}