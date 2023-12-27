// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../../libs/WitnetV2.sol";

interface IWitnetTraps {

    error NoTrap();
    error NoValue();
    error ExpiredValue();

    struct DataPoint {
        bytes   drTallyCborBytes;
        bytes16 drTrapHash;
        uint64  drTimestamp;
        uint64  finalityBlock;
    }

    struct SLA {
        bytes32 radHash;
        uint64  maxGasPrice;
        uint64  maxTimestamp;
        uint32  heartbeatSecs;
        uint32  cooldownSecs;
        uint16  reportFee10000;
        uint16  deviationThreshold10000;
        uint16  maxResultSize;
        uint8   minWitnesses;
        Witnet.RadonDataTypes dataType;
    }

    struct TrapInfo {
        bytes4    feedId;
        address   feeder;
        uint256   balance;
        bytes     bytecode;
        string    dataType;
        DataPoint lastData;
        SLA       trapSLA;
    }

    struct TrapReport {
        bytes32 drRadHash;
        bytes   drTallyCborBytes;
        uint64  drTimestamp;
        uint16  drWitnesses;
        bytes32 trapId;
    }

    enum TrapReportStatus {
        Unknown,
        Reported,
        ExcessiveGasPrice,
        InsufficientBalance,
        InsufficientCooldown,
        InsufficientDeviation,
        InsufficientWitnesses,
        InvalidRadHash,
        InvalidResult,
        InvalidSignature,
        InvalidTimestamp,
        PreviousValueNotFinalized
    }

    receive() external payable;

    function balanceOf(address feeder) external view returns (uint256);
    function estimateBaseFee(uint256 gasPrice, uint16 maxResultSize) external view returns (uint256);
    
    function fund(address feeder) external payable returns (uint256 newBalance);

    function getActiveTrapInfo(bytes32 trapId) external view returns (TrapInfo memory);
    function getActiveTrapsCount() external view returns (uint64);
    function getActiveTrapsRange(uint64 offset, uint64 length) external view returns (bytes32[] memory, TrapInfo[] memory);
  
    function getDataFeedLastUpdate(address feeder, bytes4 dataFeedId) external view returns (DataPoint memory);
    function getDataFeedLastUpdateUnsafe(address feeder, bytes4 dataFeedId) external view returns (DataPoint memory);
    function getDataFeedTrapSLA(address feeder, bytes4 dataFeedId) external view returns (SLA memory);
    
    function trapDataFeed(bytes4 dataFeedId, SLA calldata trapSLA) external payable returns (uint256 newBalance);
    function untrapDataFeed(bytes4 dataFeedId) external returns (DataPoint memory);      
    
    function reportDataFeeds(TrapReport[] calldata reports) external returns (TrapReportStatus[] memory, uint256 totalEvmReward);
    function reportDataFeeds(TrapReport[] calldata reports, bytes[] calldata signatures) external returns (TrapReportStatus[] memory);

    function withdraw() external returns (uint256 withdrawn);
}
