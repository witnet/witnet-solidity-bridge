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

    bytes32 internal constant _WITNET_BYTECODES_DATA_SLOTHASH =
        /* keccak256("io.witnet.bytecodes.data") */
        0x673359bdfd0124f9962355e7aed2d07d989b0d4bc4cbe2c94c295e0f81427dec;

    bytes internal constant _WITNET_BYTECODES_RADON_OPCODES_RESULT_TYPE =
        hex"00ffffffffffffffffffffffffffffff0401ff010203050406070101ff01ffff07ff02ffffffffffffffffffffffffff0703ffffffffffffffffffffffffffff05070404020205050505ff04ff04ffff0405070202ff04040404ffffffffffff010203050406070101ffffffffffffff02ff050404000106060707ffffffffff";

    struct Bytecodes {
        address base;
        address owner;
        address pendingOwner;
        
        Database db;
        uint256 totalDataProviders;
        // ...
    }

    struct Database {
        mapping (uint256 => WitnetV2.DataProvider) providers;
        mapping (uint256 => mapping (uint256 => bytes32[])) providersSources;
        mapping (bytes32 => uint256) providersIndex;
        
        mapping (bytes32 => bytes) reducersBytecode;
        mapping (bytes32 => bytes) retrievalsBytecode;
        mapping (bytes32 => bytes) slasBytecode;
        // mapping (bytes32 => bytes) sourceBytecodes;
        
        mapping (bytes32 => IWitnetBytecodes.RadonRetrieval) retrievals;
        mapping (bytes32 => WitnetV2.RadonReducer) reducers;
        mapping (bytes32 => WitnetV2.RadonSLA) slas;
        mapping (bytes32 => WitnetV2.DataSource) sources;
    }

    function _lookupOpcodeResultType(uint8 _opcode)
        internal pure
        returns (WitnetV2.RadonDataTypes)
    {
        if (_opcode >= _WITNET_BYTECODES_RADON_OPCODES_RESULT_TYPE.length) {
            revert IWitnetBytecodes.UnsupportedRadonScriptOpcode(_opcode);
        } else {
            uint8 _resultType = uint8(
                _WITNET_BYTECODES_RADON_OPCODES_RESULT_TYPE[_opcode]
            );
            if (_resultType == 0xff) {
                revert IWitnetBytecodes.UnsupportedRadonScriptOpcode(_opcode);
            } else if (_resultType > uint8(type(WitnetV2.RadonDataTypes).max)) {
                revert IWitnetBytecodes.UnsupportedRadonDataType(_resultType, 0);
            } else {
                return WitnetV2.RadonDataTypes(_resultType);
            }
        }
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