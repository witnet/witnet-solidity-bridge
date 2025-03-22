// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IWitOracleQueriable.sol";

interface IWitOracleQueriableConsumer {

    /// @notice Method to be called from the WitOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported.
    /// @dev It should revert if called from any other address different to the WitOracle being used
    /// @dev by the WitOracleQueriableConsumer contract. 
    /// @param queryId The unique identifier of the Witnet query being reported.
    /// @param queryResult Abi-encoded Witnet.DataResult containing the CBOR-encoded query's result, and metadata.
    function reportWitOracleQueryResult(
            Witnet.QueryId queryId,
            bytes calldata queryResult
        ) external;

    /// @notice Determines if Witnet queries can be reported from given address.
    /// @dev In practice, must only be true on the WitOracle address that's being used by
    /// @dev the WitOracleQueriableConsumer to post queries. 
    function reportableFrom(IWitOracleQueriable) external view returns (bool);
}
