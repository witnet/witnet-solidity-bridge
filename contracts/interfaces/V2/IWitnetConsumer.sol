// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../libs/Witnet.sol";

interface IWitnetConsumer {

    /// @notice Method to be called from the WitnetRequestBoard contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported with no errors.
    /// @dev It should revert if called from any other address different to the WitnetRequestBoard being used
    /// @dev by the WitnetConsumer contract. Within the implementation of this method, the WitnetConsumer
    /// @dev can call to the WRB as to retrieve the Witnet tracking information (i.e. the `witnetDrTxHash` 
    /// @dev and `witnetDrCommitTimestamp`), or the finality status, of the result being reported.
    /// @param queryId The unique identifier of the Witnet query being reported.
    /// @param cborValue The CBOR-encoded resulting value of the Witnet query being reported.
    function reportWitnetQueryResult(
            uint256 queryId, 
            WitnetCBOR.CBOR calldata cborValue
        ) external;

    /// @notice Method to be called from the WitnetRequestBoard contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported WITH errors.
    /// @dev It should revert if called from any other address different to the WitnetRequestBoard being used
    /// @dev by the WitnetConsumer contract. Within the implementation of this method, the WitnetConsumer
    /// @dev can call to the WRB as to retrieve the Witnet tracking information (i.e. the `witnetDrTxHash` 
    /// @dev and `witnetDrCommitTimestamp`), or the finality status, of the result being reported.
    /// @param queryId The unique identifier of the Witnet query being reported.
    /// @param errorCode The error code enum identifying the error produced during resolution on the Witnet blockchain.
    /// @param errorArgs Error arguments, if any. An empty buffer is to be passed if no error arguments apply.
    function reportWitnetQueryError(
            uint256 queryId, 
            Witnet.ResultErrorCodes errorCode, 
            WitnetCBOR.CBOR calldata errorArgs
        ) external;

    /// @notice Determines if Witnet queries can be reported from given address.
    /// @dev In practice, must only be true on the WitnetRequestBoard address that's being used by
    /// @dev the WitnetConsumer to post queries. 
    function reportableFrom(address) external view returns (bool);
}