// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title The Witnet Request Board Reporter interface.
/// @author The Witnet Foundation.
interface IWitnetRequestBoardReporter {
    /// Reports the Witnet-provided result to a previously posted request. 
    /// @dev Will assume `block.number` as the epoch number for the provided result.
    /// @dev Fails if:
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_proof` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param _queryId The unique identifier of the data request.
    /// @param _proof of the solving tally transaction in Witnet.
    /// @param _result The result itself as bytes.
    function reportResult(uint256 _queryId, bytes32 _proof, bytes calldata _result) external;

    /// Reports the Witnet-provided result to a previously posted request.
    /// @dev Fails if:
    /// @dev - called from unauthorized address;
    /// @dev - the `_queryId` is not in 'Posted' status.
    /// @dev - provided `_proof` is zero;
    /// @dev - length of provided `_result` is zero.
    /// @param _queryId The unique query identifier
    /// @param _epoch of the solving tally transaction in Witnet.
    /// @param _proof of the solving tally transaction in Witnet.
    /// @param _result The result itself as bytes.
    function reportResult(uint256 _queryId, uint256 _epoch, bytes32 _proof, bytes calldata _result) external;
}
