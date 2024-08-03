// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetRadonRegistryData {
    
    bytes32 private constant _WITNET_BYTECODES_DATA_SLOTHASH =
        /* keccak256("io.witnet.bytecodes.data") */
        0x673359bdfd0124f9962355e7aed2d07d989b0d4bc4cbe2c94c295e0f81427dec;

    struct Storage {
        address base;
        address owner;
        address pendingOwner;
        
        Database db;
    }

    struct DataProvider {
        string  authority;
        uint256 totalEndpoints;
        mapping (uint256 => bytes32) endpoints;
    }

    struct RadonRequestPacked {
        string[][] _args;
        bytes32 aggregateTallyHashes;
        bytes32 _radHash;
        Witnet.RadonDataTypes _resultDataType;
        uint16 _resultMaxSize;
        bytes32[] retrievals;
        bytes32 legacyTallyHash;
    }

    struct Database {
        bytes32 _reservedSlot0;
        bytes32 _reservedSlot1;
        
        mapping (bytes32 => Witnet.RadonReducer) reducers;
        mapping (bytes32 => Witnet.RadonRetrieval) retrievals;
        mapping (bytes32 => RadonRequestPacked) requests;
        mapping (bytes32 => bytes32) rads;
        mapping (bytes32 => bytes) radsBytecode;
    }

    constructor() {
        // auto-initialize upon deployment
        __bytecodes().base = address(this);
    }


    // ================================================================================================================
    // --- Internal state-modifying functions -------------------------------------------------------------------------
    
    /// @dev Returns storage pointer to contents of 'Storage' struct.
    function __bytecodes()
      internal pure
      returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WITNET_BYTECODES_DATA_SLOTHASH
        }
    }

    /// @dev Returns storage pointer to contents of 'Database' struct.
    function __database()
      internal view
      returns (Database storage _ptr)
    {
        return __bytecodes().db;
    }

    function __requests(bytes32 _radHash)
        internal view
        returns (RadonRequestPacked storage _ptr)
    {
        return __database().requests[_radHash];
    }
}