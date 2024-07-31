// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";
import "../WitnetRequest.sol";

interface IWitnetFeedsAdmin {
    function acceptOwnership() external;
    function baseFeeOverheadPercentage() external view returns (uint16);
    function deleteFeed(string calldata caption) external;
    function deleteFeeds() external;
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function settleBaseFeeOverheadPercentage(uint16) external;
    function settleDefaultRadonSLA(Witnet.RadonSLA calldata) external;
    function settleFeedRequest(string calldata caption, bytes32 radHash) external;
    function settleFeedRequest(string calldata caption, WitnetRequest request) external;
    function settleFeedRequest(string calldata caption, IWitnetRequestTemplate template, string[][] calldata) external;
    function settleFeedSolver (string calldata caption, address solver, string[] calldata deps) external;
    function transferOwnership(address) external;
}