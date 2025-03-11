// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/Witnet.sol";

import "../../WitOracleRequest.sol";
import "../../WitOracleRequestTemplate.sol";

interface IWitPriceFeedsLegacyAdmin {

    event WitFeedDeleted(string caption, bytes4 feedId);
    event WitFeedSettled(string caption, bytes4 feedId, bytes32 radHash);
    event WitFeedSolverSettled(string caption, bytes4 feedId, address solver);

    function acceptOwnership() external;
    function baseFeeOverheadPercentage() external view returns (uint16);
    function deleteFeed(string calldata caption) external;
    function deleteFeeds() external;
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function settleBaseFeeOverheadPercentage(uint16) external;
    function settleDefaultUpdateSLA(uint16, uint64) external;
    function settleFeedRequest(string calldata caption, bytes32 radHash) external;
    function settleFeedRequest(string calldata caption, WitOracleRequest request) external;
    function settleFeedRequest(string calldata caption, WitOracleRequestTemplate template, string[][] calldata) external;
    function settleFeedSolver (string calldata caption, address solver, string[] calldata deps) external;
    function transferOwnership(address) external;
}
