// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/Witnet.sol";

interface IWitOracleConsumer {

    /// @notice Method to be called from the WitOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported with no errors.
    /// @dev It should revert if called from any other address different to the WitOracle being used
    /// @dev by the WitOracleConsumer contract. 
    /// @param queryId The unique identifier of the Witnet query being reported.
    /// @param resultDrTxHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param resultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param resultEvmFinalityBlock EVM block at which the provided data can be considered to be final.
    /// @param witnetResultCborValue The CBOR-encoded resulting value of the Witnet query being reported.
    function reportWitOracleResultValue(
            uint256 queryId, 
            uint64  resultTimestamp,
            bytes32 resultDrTxHash,
            uint256 resultEvmFinalityBlock,
            WitnetCBOR.CBOR calldata witnetResultCborValue
        ) external;

    /// @notice Method to be called from the WitOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported WITH errors.
    /// @dev It should revert if called from any other address different to the WitOracle being used
    /// @dev by the WitOracleConsumer contract. 
    /// @param queryId The unique identifier of the Witnet query being reported.
    /// @param resultDrTxHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param resultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param resultEvmFinalityBlock EVM block at which the provided data can be considered to be final.
    /// @param errorCode The error code enum identifying the error produced during resolution on the Witnet blockchain.
    /// @param errorArgs Error arguments, if any. An empty buffer is to be passed if no error arguments apply.
    function reportWitOracleResultError(
            uint256 queryId, 
            uint64  resultTimestamp,
            bytes32 resultDrTxHash,
            uint256 resultEvmFinalityBlock,
            Witnet.ResultErrorCodes errorCode, 
            WitnetCBOR.CBOR calldata errorArgs
        ) external;

    /// @notice Determines if Witnet queries can be reported from given address.
    /// @dev In practice, must only be true on the WitOracle address that's being used by
    /// @dev the WitOracleConsumer to post queries. 
    function reportableFrom(address) external view returns (bool);
}