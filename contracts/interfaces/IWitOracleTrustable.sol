// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleTrustable {
    
    /// @notice Verify the push data report is valid and was actually signed by a trustable reporter,
    /// @notice reverting if verification fails, or returning a Witnet.DataResult struct otherwise.
    function pushData(Witnet.DataPushReport calldata, bytes calldata signature) external returns (Witnet.DataResult memory);

    /// @notice Verify the push data report is valid, reverting if not valid or not reported from an authorized 
    /// @notice reporter, or returning a Witnet.DataResult struct otherwise.
    function pushData(Witnet.DataPushReport calldata) external returns (Witnet.DataResult memory);
}
