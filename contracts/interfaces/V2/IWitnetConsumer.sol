// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libs/Witnet.sol";

interface IWitnetConsumer {

    /// @notice Method to be called from the WitnetRequestBoard contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported with no errors.
    /// @dev It should revert if called from any other address different to the WitnetRequestBoard being used
    /// @dev by the WitnetConsumer contract. Within the implementation of this method, the WitnetConsumer
    /// @dev can call to the WRB as to retrieve the Witnet tracking information (i.e. the `witnetDrTxHash` 
    /// @dev and `witnetDrCommitTxTimestamp`), or the finality status, of the result being reported.
    /// @param witnetQueryId The unique identifier of the Witnet query being reported.
    /// @param witnetResultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param witnetResultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param witnetEvmFinalityBlock EVM block at which the provided data can be considered to be final.
    /// @param witnetResultCborValue The CBOR-encoded resulting value of the Witnet query being reported.
    function reportWitnetQueryResult(
            uint256 witnetQueryId, 
            uint64  witnetResultTimestamp,
            bytes32 witnetResultTallyHash,
            uint256 witnetEvmFinalityBlock,
            WitnetCBOR.CBOR calldata witnetResultCborValue
        ) external;

    /// @notice Method to be called from the WitnetRequestBoard contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported WITH errors.
    /// @dev It should revert if called from any other address different to the WitnetRequestBoard being used
    /// @dev by the WitnetConsumer contract. Within the implementation of this method, the WitnetConsumer
    /// @dev can call to the WRB as to retrieve the Witnet tracking information (i.e. the `witnetDrTxHash` 
    /// @dev and `witnetDrCommitTxTimestamp`), or the finality status, of the result being reported.
    /// @param witnetQueryId The unique identifier of the Witnet query being reported.
    /// @param witnetQueryId The unique identifier of the Witnet query being reported.
    /// @param witnetResultTallyHash Hash of the commit/reveal witnessing act that took place in the Witnet blockahin.
    /// @param witnetResultTimestamp Timestamp at which the reported value was captured by the Witnet blockchain. 
    /// @param witnetEvmFinalityBlock EVM block at which the provided data can be considered to be final.
    /// @param errorCode The error code enum identifying the error produced during resolution on the Witnet blockchain.
    /// @param errorArgs Error arguments, if any. An empty buffer is to be passed if no error arguments apply.
    function reportWitnetQueryError(
            uint256 witnetQueryId, 
            uint64  witnetResultTimestamp,
            bytes32 witnetResultTallyHash,
            uint256 witnetEvmFinalityBlock,
            Witnet.ResultErrorCodes errorCode, 
            WitnetCBOR.CBOR calldata errorArgs
        ) external;

    /// @notice Determines if Witnet queries can be reported from given address.
    /// @dev In practice, must only be true on the WitnetRequestBoard address that's being used by
    /// @dev the WitnetConsumer to post queries. 
    function reportableFrom(address) external view returns (bool);
}