// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleTrustable {
    
    /// @notice Verify the provided report was actually signed by a trustable reporter,
    /// @notice reverting if verification fails, or returning the contained data a Witnet.Result value.
    function pushData(Witnet.DataPushReport calldata, bytes calldata signature) external returns (Witnet.DataResult memory);
}
