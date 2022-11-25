// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";

/// @title Witnet Request Board emitting events interface.
/// @author The Witnet Foundation.
interface IWitnetRequests {

    struct Stats {
        uint256 totalDisputes;
        uint256 totalPosts;
        uint256 totalReports;
        uint256 totalUpgrades;
    }

    error DrPostBadDisputer(bytes32 drHash, address disputer);
    error DrPostBadEpochs(bytes32 drHash, uint256 drPostEpoch, uint256 drCommitTxEpoch, uint256 drTallyTxEpoch);
    error DrPostBadMood(bytes32 drHash, WitnetV2.DrPostStatus currentStatus);  
    error DrPostLowReward(bytes32 drHash, uint256 minBaseFee, uint256 weiValue);
    error DrPostNotInStatus(bytes32 drHash, WitnetV2.DrPostStatus currentStatus, WitnetV2.DrPostStatus requiredStatus);
    error DrPostOnlyRequester(bytes32 drHash, address requester);
    error DrPostOnlyReporter(bytes32 drHash, address reporter);

    event DrPost(WitnetV2.DrPostRequest request);
    event DrPostDeleted (address indexed from, bytes32 drHash);
    event DrPostDisputed(address indexed from, bytes32 drHash);
    event DrPostReported(address indexed from, bytes32 drHash);
    event DrPostUpgraded(address indexed from, bytes32 drHash, uint256 weiReward);
    event DrPostVerified(address indexed from, bytes32 drHash);  

    function estimateBaseFee(bytes32 _drRadHash, uint256 _gasPrice, bytes32 _drSlaHash, uint256 _witPrice) external view returns (uint256);
    function estimateReportFee(bytes32 _drRadHash, uint256 _gasPrice) external view returns (uint256);
    
    function getDrPost(bytes32 _drHash) external view returns (WitnetV2.DrPost memory);
    function getDrPostEpoch(bytes32 _drHash) external view returns (uint256);
    function getDrPostResponse(bytes32 _drHash) external view returns (WitnetV2.DrPostResponse memory);
    function getDrPostStatus(bytes32 _drHash) external view returns (WitnetV2.DrPostStatus);
    function readDrPostResultBytes(bytes32 _drHash) external view returns (bytes memory);
    function serviceStats() external view returns (Stats memory);
    function serviceTag() external view returns (bytes4);
    
    function postDr(bytes32 _drRadHash, bytes32 _drSlaHash, uint256 _witPrice) external payable returns (bytes32 _drHash);

    function deleteDrPost(bytes32 _drHash) external;
    function deleteDrPostRequest(bytes32 _drHash) external;
    function disputeDrPost(bytes32 _drHash) external payable;
    function reportDrPost(
            bytes32 _drHash,
            uint256 _drCommitTxEpoch,
            uint256 _drTallyTxEpoch,
            bytes32 _drTallyTxHash,
            bytes calldata _drTallyResultCborBytes
        ) external payable;
    function upgradeDrPostReward(bytes32 _drHash) external payable;
    function verifyDrPost(
            bytes32 _drHash,
            uint256 _drCommitTxEpoch,
            uint256 _drTallyTxEpoch,
            uint256 _drTallyTxIndex,
            bytes32 _blockDrTallyTxsRoot,            
            bytes32[] calldata _blockDrTallyTxHashes,
            bytes calldata _drTallyTxBytes
        ) external payable;
    
}