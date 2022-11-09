// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitnetRequests.sol";

interface IWitnetBlocks {

    event Hooked(address indexed from);
    event Rollup(address indexed from, uint256 index, uint256 prevIndex);
    event Slashed(address indexed from, uint256 index, uint256 prevIndex);

    function getBlockDrTxsRoot(uint256 _witnetEpoch) external view returns (bytes32 _blockHash, bytes32 _txsRoot);
    function getBlockDrTallyTxsRoot(uint256 _witnetEpoch) external view returns (bytes32 _blockHash, bytes32 _txsRoot);
    function getBlockStatus(uint256 _witnetEpoch) external view returns (WitnetV2.BlockStatus);
    
    function getLastBeacon() external view returns (WitnetV2.Beacon memory);
    function getLastBeaconIndex() external view returns (uint256);
    function getLastBeaconStatus() external view returns (WitnetV2.BeaconStatus);
    
    function getNextBeaconEvmBlock() external view returns (uint256);
    function getNextBeaconIndex() external view returns (uint256);
      
    function rollupNext() external payable;
    function rollupForward() external payable;

    function setupForward() external payable;

    function verifyNext() external;    
    function verifyForward() external;

    function hook(IWitnetRequests) external;
}