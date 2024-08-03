// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

import "../WitnetRequest.sol";
import "../WitnetRequestTemplate.sol";

interface IWitnetFeedsAdmin {

    event WitnetFeedDeleted(bytes4 feedId);
    event WitnetFeedSettled(bytes4 feedId, bytes32 radHash);
    event WitnetFeedSolverSettled(bytes4 feedId, address solver);
    event WitnetRadonSLA(Witnet.RadonSLA sla);

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
    function settleFeedRequest(string calldata caption, WitnetRequestTemplate template, string[][] calldata) external;
    function settleFeedSolver (string calldata caption, address solver, string[] calldata deps) external;
    function transferOwnership(address) external;
}