// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IFeeds {
    function footprint() external view returns (bytes4);
    function hash(string calldata caption) external pure returns (bytes4);
    function lookupCaption(bytes4) external view returns (string memory);
    function supportedFeeds() external view returns (bytes4[] memory, string[] memory, bytes32[] memory);
    function supportsCaption(string calldata) external view returns (bool);
    function totalFeeds() external view returns (uint256);
}