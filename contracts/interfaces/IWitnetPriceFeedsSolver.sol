// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetPriceFeedsSolver {
    struct Price {
        uint value;
        uint timestamp;
        bytes32 tallyHash;
        Witnet.ResponseStatus status;
    }
    function class() external pure returns (string memory);
    function delegator() external view returns (address);
    function solve(bytes4 feedId) external view returns (Price memory);
    function specs() external pure returns (bytes4);
    function validate(bytes4 feedId, string[] calldata initdata) external;
}