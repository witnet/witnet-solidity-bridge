// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseQueriableTrustable.sol";

/// @title Queriable WitOracle "trustable" implementation for Obscuro/TEN chains.
/// @author The Witnet Foundation
contract WitOracleTrustableObscuro
    is 
        WitOracleBaseQueriableTrustable
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleBaseQueriableTrustable).name;
    }

    constructor(
            EvmImmutables memory _immutables,
            WitOracleRadonRegistry _registry,
            bytes32 _versionTag
        )
        WitOracleBaseQueriable(
            _immutables,
            _registry
        )
        WitOracleBaseQueriableTrustable(_versionTag)
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

    function getQueryResult(Witnet.QueryId _queryId)
        virtual override
        public view
        onlyRequester(_queryId)
        returns (Witnet.DataResult memory)
    {
        return WitOracleBaseQueriable.getQueryResult(_queryId);
    }

    function getQueryResultStatus(Witnet.QueryId _queryId)
        virtual override
        public view
        onlyRequester(_queryId)
        returns (Witnet.ResultStatus)
    {
        return super.getQueryResultStatus(_queryId);
    }

    function getQueryResultStatusDescription(Witnet.QueryId _queryId)
        virtual override
        public view
        onlyRequester(_queryId)
        returns (string memory)
    {
        return WitOracleBaseQueriable.getQueryResultStatusDescription(_queryId);
    }
}
