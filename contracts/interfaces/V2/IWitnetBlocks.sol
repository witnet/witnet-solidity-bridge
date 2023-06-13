// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitnetRequestBoardV2.sol";

interface IWitnetBlocks {

    event FastForward(address indexed from, uint256 index, uint256 prevIndex);
    event Rollup(address indexed from, uint256 index, uint256 tallyCount, uint256 weiReward);

    function ROLLUP_DEFAULT_PENALTY_WEI() external view returns (uint256);
    function ROLLUP_MAX_GAS() external view returns (uint256);
    
    function board() external view returns (IWitnetRequestBoardV2);
    function class() external pure returns (bytes4);
    function genesis() external view returns (WitnetV2.Beacon memory);
    
    function getBeaconDisputedQueries(uint256 beaconIndex) external view returns (bytes32[] memory);
    function getCurrentBeaconIndex() external view returns (uint256);
    function getCurrentEpoch() external view returns (uint256);
    function getLastBeacon() external view returns (WitnetV2.Beacon memory);
    function getLastBeaconEpoch() external view returns (uint256);
    function getLastBeaconIndex() external view returns (uint256);
    function getNextBeaconIndex() external view returns (uint256);

    function disputeQuery(bytes32 queryHash, uint256 tallyBeaconIndex) external;
    function rollupTallyHashes(
            WitnetV2.FastForward[] calldata fastForwards, 
            bytes32[] calldata tallyHashes, 
            uint256 tallyOffset, 
            uint256 tallyLength
        ) external returns (uint256 weiReward);
}