// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";
import "../../requests/WitnetRequest.sol";

interface IWitnetFeedsAdmin {
    function deleteFeed(string calldata caption) external;
    function settleDefaultRadonSLA(WitnetV2.RadonSLA calldata) external;
    function settleFeedRequest(string calldata caption, bytes32 radHash) external;
    function settleFeedRequest(string calldata caption, WitnetRequest request) external;
    function settleFeedRequest(string calldata caption, WitnetRequestTemplate template, string[][] calldata) external;
    function settleFeedSolver(string calldata caption, address solver) external;
}