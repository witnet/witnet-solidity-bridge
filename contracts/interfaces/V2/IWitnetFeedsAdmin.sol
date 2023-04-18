// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";

interface IWitnetFeedsAdmin {
    function deleteFeed(string calldata caption) external;
    function settleFeed(string calldata caption, bytes32 radHash) external;
    function settleFeedSolver(string calldata caption, address solver) external;
    function settleRadonSLA(WitnetV2.RadonSLA calldata) external;
}