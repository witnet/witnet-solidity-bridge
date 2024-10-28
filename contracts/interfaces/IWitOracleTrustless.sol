// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleTrustless {

    /// @notice Verify the data report was actually produced by the Wit/oracle sidechain,
    /// @notice reverting if the verification fails, or returning the self-contained Witnet.Result value.
    function pushData(
            Witnet.DataPushReport calldata report, 
            Witnet.FastForward[] calldata rollup, 
            bytes32[] calldata droTalliesTrie
        ) 
        external returns (Witnet.DataResult memory);
}
