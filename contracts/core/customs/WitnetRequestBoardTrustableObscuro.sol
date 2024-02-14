// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../defaults/WitnetRequestBoardTrustableDefault.sol";

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
            WitnetRequestBytecodes _registry,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas
        )
        WitnetRequestBoardTrustableDefault(
            _factory, 
            _registry,
            _upgradable, 
            _versionTag,
            _reportResultGasBase,
            _reportResultWithCallbackGasBase,
            _reportResultWithCallbackRevertGasBase,
            _sstoreFromZeroGas
        )
    {}

    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetOracleView' ------------------------------------------------------

    /// @notice Gets the whole Query data contents, if any, no matter its current status.
    /// @dev Fails if or if `msg.sender` is not the actual requester.
    function getQuery(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (WitnetV2.Query memory)
    {
        return WitnetRequestBoardTrustableBase.getQuery(_queryId);
    }

    /// @notice Retrieves the whole `Witnet.Response` record referred to a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or if `msg.sender` is not the actual requester.
    /// @param _queryId The unique query identifier
    function getQueryResponse(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (WitnetV2.Response memory _response)
    {
        return WitnetRequestBoardTrustableBase.getQueryResponse(_queryId);
    }

    /// @notice Retrieves the Witnet-provable CBOR-bytes result of a previously posted request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or if `msg.sender` is not the actual requester.
    /// @param _queryId The unique query identifier
    function getQueryResult(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.Result memory)
    {
        return WitnetRequestBoardTrustableBase.getQueryResult(_queryId);
    }
    
}
