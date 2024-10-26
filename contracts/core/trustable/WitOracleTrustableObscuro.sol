// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseTrustable.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustableObscuro
    is 
        WitOracleBaseTrustable
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleBaseTrustable).name;
    }

    constructor(
            EvmImmutables memory _immutables,
            WitOracleRadonRegistry _registry,
            bytes32 _versionTag
        )
        WitOracleBase(
            _immutables,
            _registry
        )
        WitOracleBaseTrustable(_versionTag)
    {}

    // ================================================================================================================
    // --- Overrides 'IWitOracle' -------------------------------------------------------------------------------------

    /// @notice Gets the whole Query data contents, if any, no matter its current status.
    /// @dev Fails if or if `msg.sender` is not the actual requester.
    function getQuery(Witnet.QueryId _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.Query memory)
    {
        return super.getQuery(_queryId);
    }

    /// @notice Retrieves the whole `Witnet.QueryResponse` record referred to a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or if `msg.sender` is not the actual requester.
    /// @param _queryId The unique query identifier
    function getQueryResponse(Witnet.QueryId _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.QueryResponse memory _response)
    {
        return super.getQueryResponse(_queryId);
    }

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param _queryId The unique query identifier.
    function getQueryResultError(Witnet.QueryId _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.ResultError memory)
    {
        return super.getQueryResultError(_queryId);
    }  
}
