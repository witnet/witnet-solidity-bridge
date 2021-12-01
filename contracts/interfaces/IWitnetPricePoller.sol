// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetRequestBoard.sol";

interface IWitnetPricePoller {

    event PricePolling(address indexed from, uint256 queryId, uint256 extraFee);

    function lastPrice() external view returns (int256);
    function lastTimestamp() external view returns (uint256);    
    function lastValue() external view returns (int, uint, bytes32);

    function latestUpdateErrorMessage() external view returns (string memory);
    function latestUpdateStatus() external view returns (uint256);

    function pendingUpdate() external view returns (bool);
    function requestUpdate() external payable;

    function supportsInterface(bytes4) external view returns (bool);

}
