// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitnetRequestBoardV2.sol";

interface IWitnetBlocks {

    event Rollup(address indexed from, uint256 index, uint256 prevIndex);
    
    function board() external view returns (IWitnetRequestBoardV2);
    function class() external pure returns (bytes4);
    function genesis() external view returns (WitnetV2.Beacon memory);
    function getLastBeacon() external view returns (WitnetV2.Beacon memory);
    function getLastBeaconIndex() external view returns (uint256);
    function getCurrentBeaconIndex() external view returns (uint256);
    function getNextBeaconIndex() external view returns (uint256);
}