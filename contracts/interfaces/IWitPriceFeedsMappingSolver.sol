// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitPriceFeedsMappingSolver {
    function class() external pure returns (string memory);
    function delegator() external view returns (address);
    function solve(bytes4 feedId) external view returns (bytes memory);
    function specs() external pure returns (bytes4);
    function validate(bytes4 feedId, string[] calldata initdata) external;
}
