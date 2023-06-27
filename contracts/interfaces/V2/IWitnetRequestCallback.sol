// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";

interface IWitnetRequestCallback {
    function settleWitnetQueryReport(
        bytes32 queryHash,  
        WitnetV2.QueryReport calldata queryReport
    ) external;
}