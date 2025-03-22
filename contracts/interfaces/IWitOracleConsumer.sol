// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../libs/Witnet.sol";

interface IWitOracleConsumer {

    /// @notice Method to be called from the WitOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported.
    /// @dev It should revert if called from any other address different to the WitOracle being used
    /// @dev by the WitOracleConsumer contract. 
    /// @param queryId The unique identifier of the Witnet query being reported.
    /// @param queryResult Bytes-encoded Witnet.DataResult containing result CBOR value, and metadata.
    function reportWitOracleQueryResult(
            Witnet.QueryId queryId,
            bytes calldata queryResult
        ) external;

    /// @notice Determines if Witnet queries can be reported from given address.
    /// @dev In practice, must only be true on the WitOracle address that's being used by
    /// @dev the WitOracleConsumer to post queries. 
    function reportableFrom(address) external view returns (bool);
}
