// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title The Witnet Request Board Reporter interface.
/// @author The Witnet Foundation.
interface IWitnetRequestBoardReporter {
    /// Reports the Witnet-provided result to a previously posted request. 
    /// @dev Will asume `block.number` as the Witnet epoch number of the provided result.
    /// @dev Fails if:
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_witnetProof` is zero;
    /// @dev - length of provided `_witnetValue` is zero.
    /// @param _queryId The unique identifier of the data request.
    /// @param _witnetProof of the solving tally transaction in Witnet.
    /// @param _witnetResult The result itself as bytes.
    function reportResult(uint256 _queryId, bytes32 _witnetProof, bytes calldata _witnetResult) external;

    /// Reports the Witnet-provided result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_witnetProof` is zero;
    /// @dev - length of provided `_witnetValue` is zero.
    /// @param _queryId The unique identifier of the request.
    /// @param _witnetEpoch of the solving tally transaction in Witnet.
    /// @param _witnetProof of the solving tally transaction in Witnet.
    /// @param _witnetResult The result itself as bytes.
    function reportResult(uint256 _queryId, uint256 _witnetEpoch, bytes32 _witnetProof, bytes calldata _witnetResult) external;
}
