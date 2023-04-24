// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitnetFeedsEvents {
    event DeletedFeed(address indexed from, bytes4 indexed feedId, string caption);
    event SettledFeed(address indexed from, bytes4 indexed feedId, string caption, bytes32 radHash);
    event SettledFeedSolver(address indexed from, bytes4 indexed feedId, string caption, address solver);
    event SettledRadonSLA(address indexed from, bytes32 slaHash);
    event UpdatingFeed(address indexed from, bytes4 indexed feedId, bytes32 slaHash, uint256 value);
    event UpdatingFeedReward(address indexed from, bytes4 indexed feedId, uint256 value);
}