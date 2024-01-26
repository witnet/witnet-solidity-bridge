// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetRequestBoardTrustableDefault.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableObscuro
    is 
        WitnetRequestBoardTrustableDefault
{
    constructor(
            WitnetRequestFactory _factory,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasLimit
        )
        WitnetRequestBoardTrustableDefault(
            _factory, 
            _upgradable, 
            _versionTag,
            _reportResultGasLimit
        )
    {}

    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetRequestBoardView' ------------------------------------------------------

    /// @notice Retrieves the whole Request record posted to the Witnet Request Board.
    /// @dev Fails if the `_queryId` is not valid or, if it has already been reported
    /// @dev or deleted, or if `msg.sender` is not the actual requester.
    /// @param _queryId The unique identifier of a previously posted query.
    function readRequest(uint256 _queryId)
        public view 
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.Request memory)
    {
        return WitnetRequestBoardTrustableBase.readRequest(_queryId);
    }

    /// Retrieves the Witnet-provided result, and metadata, to a previously posted request.    
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or if `msg.sender` is not the actual requester.
    /// @param _queryId The unique query identifier
    function readResponse(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.Response memory _response)
    {
        return WitnetRequestBoardTrustableBase.readResponse(_queryId);
    }

    /// Retrieves the Witnet-provided CBOR-bytes result of a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or if `msg.sender` is not the actual requester.
    /// @param _queryId The unique query identifier
    function readResponseResult(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.Result memory)
    {
        return WitnetRequestBoardTrustableBase.readResponseResult(_queryId);
    }
    
}
