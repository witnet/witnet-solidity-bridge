// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitOracleRadonRegistryData {
    
    bytes32 private constant _WIT_BYTECODES_DATA_SLOTHASH =
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

    struct RadonRequestLegacyPacked {
        string[][] _args;
        bytes32 aggregateTallyHashes;
        bytes32 _radHash;
        Witnet.RadonDataTypes _resultDataType;
        uint16 _resultMaxSize;
        bytes32[] retrievals;
        bytes32 legacyTallyHash;
    }

    struct RadonRequestInfo {
        bytes15 crowdAttestationTallyHash;
        uint8   dataSourcesCount;
        bytes15 dataSourcesAggregatorHash;
        Witnet.RadonDataTypes resultDataType;
    }

    struct Database {
        bytes32 _reservedSlot0;
        bytes32 _reservedSlot1;
        mapping (bytes32 => Witnet.RadonReducer) reducers;
        mapping (bytes32 => Witnet.RadonRetrieval) retrievals;
        mapping (Witnet.RadonHash => RadonRequestLegacyPacked) legacyRequests;
        mapping (bytes32 => Witnet.RadonHash) rads;
        mapping (Witnet.RadonHash => bytes) radsBytecode;
        mapping (Witnet.RadonHash => RadonRequestInfo) radsInfo;
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
            _ptr.slot := _WIT_BYTECODES_DATA_SLOTHASH
        }
    }

    /// @dev Returns storage pointer to contents of 'Database' struct.
    function __database()
      internal view
      returns (Database storage _ptr)
    {
        return __bytecodes().db;
    }

    function __requests(Witnet.RadonHash _radHash)
        internal view
        returns (RadonRequestLegacyPacked storage _ptr)
    {
        return __database().legacyRequests[_radHash];
    }
}