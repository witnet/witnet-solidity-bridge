// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/V2/IWitnetTraps.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetTrapsData {  

    using WitnetV2 for WitnetV2.Request;

    bytes32 internal constant _WITNET_TRAPS_DATA_SLOTHASH =
        /* keccak256("io.witnet.traps.data") */
        0xb44c98929a7f33726003754788fddc0e0449de5db2ff77e156bc994df2bb5916;
    
    struct Storage {
        address base;
        mapping (address => uint256) balances;
        mapping (address => bool) isReporter;
        mapping (bytes32 => TrapStorage) traps;
        bytes32[] trapIds;
    }

    struct TrapStorage {
        uint64  index;
        bytes4  feedId;
        address feeder;
        bytes32 dataPtr;
        bytes32 prevDataPtr;
        IWitnetTraps.SLA sla;
    }

    struct DataPointPacked {
        bytes   drTallyCborBytes;
        bytes32 packed;
    }

    modifier onlyReporters {
        require(
            __storage().isReporter[msg.sender],
            "WitnetTraps: unauthorized reporter"
        ); _;
    }

    modifier trapIsOwned(address feeder, bytes4 feedId) {
        if (__seekTrap(feeder, feedId).feeder != feeder) {
            revert IWitnetTraps.NoTrap();
        } _;
    }

    constructor() {}

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _extractDataPoint(bytes32 _storagePtr) internal view returns (IWitnetTraps.DataPoint memory) {
        DataPointPacked storage __data = __seekDataPointPacked(_storagePtr);
        bytes32 _packed = __data.packed;
        return IWitnetTraps.DataPoint({
            drTallyCborBytes: __data.drTallyCborBytes,
            drTrapHash: bytes16(_packed >> 128),
            drTimestamp: uint64(uint(_packed >> 192)),
            finalityBlock: uint64(uint(_packed))
        });
    }

    function _extractDataPointFinalityBlock(bytes32 _storagePtr) internal view returns (uint64) {
        return uint64(uint(__seekDataPointPacked(_storagePtr).packed));
    }

    function _extractDataPointFinalityBlockAndTimestamp(bytes32 _storagePtr) internal view returns (uint64, uint64) {
        bytes32 _packed = __seekDataPointPacked(_storagePtr).packed;
        return (
            uint64(uint(_packed)),
            uint64(uint(_packed) >> 64)
        );
    }
    
    function _hashTrap(address trapper, bytes4 feedId) internal pure returns (bytes32) {
        return keccak256(abi.encode(trapper, feedId));
    }

    function __seekDataPointPacked(bytes32 _storagePtr) internal pure returns (DataPointPacked storage data) {
        assembly {
            data.slot := _storagePtr
        }
    }

    /// Gets trap storage by query id.
    function __seekTrap(bytes32 trapId) internal view returns (TrapStorage storage) {
        return __storage().traps[trapId];
    }

    function __seekTrap(address trapper, bytes4 dataFeedId)
        internal view 
        returns (TrapStorage storage)
    {
        return __storage().traps[_hashTrap(trapper, dataFeedId)];
    }

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function __storage() internal pure returns (Storage storage data) {
        assembly {
            data.slot := _WITNET_TRAPS_DATA_SLOTHASH
        }
    }
}
