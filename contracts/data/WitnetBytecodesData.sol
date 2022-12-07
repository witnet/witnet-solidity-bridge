// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interfaces/V2/IWitnetBytecodes.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetBytecodesData
    is
        ERC165, 
        IWitnetBytecodes
{

    bytes32 private constant _WITNET_BYTECODES_DATA_SLOTHASH =
        /* keccak256("io.witnet.bytecodes.data") */
        0x673359bdfd0124f9962355e7aed2d07d989b0d4bc4cbe2c94c295e0f81427dec;

    struct Bytecodes {
        address base;
        address owner;
        address pendingOwner;
        
        Database db;
        uint256 totalDataProviders;
        // ...
    }

    struct RadonRetrieval {
        WitnetV2.RadonDataTypes dataType;
        uint16 dataMaxSize;
        string[][] args;
        bytes32[] sources;
        bytes32 aggregator;
        bytes32 tally;        
    }

    struct Database {
        mapping (uint256 => WitnetV2.DataProvider) providers;
        mapping (bytes32 => uint256) providersIndex;
        
        mapping (bytes32 => WitnetV2.RadonReducer) reducers;
        mapping (bytes32 => RadonRetrieval) retrievals;
        mapping (bytes32 => WitnetV2.RadonSLA) slas;
        mapping (bytes32 => WitnetV2.DataSource) sources;
    }


    // ================================================================================================================
    // --- Internal state-modifying functions -------------------------------------------------------------------------
    
    /// @dev Returns storage pointer to contents of 'Bytecodes' struct.
    function __bytecodes()
      internal pure
      returns (Bytecodes storage _ptr)
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

    function __retrieval(bytes32 _drRetrievalHash)
        internal view
        returns (RadonRetrieval storage _ptr)
    {
        return __database().retrievals[_drRetrievalHash];
    }

}