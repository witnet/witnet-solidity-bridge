// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleTrustableDefault.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustableObscuro
    is 
        WitOracleTrustableDefault
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleTrustableObscuro).name;
    }

    constructor(
            WitOracleRadonRegistry _registry,
            WitOracleRequestFactory _factory,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas
        )
        WitOracleTrustableDefault(
            _registry,
            _factory, 
            _upgradable, 
            _versionTag,
            _reportResultGasBase,
            _reportResultWithCallbackGasBase,
            _reportResultWithCallbackRevertGasBase,
            _sstoreFromZeroGas
        )
    {}


    // ================================================================================================================
    // --- Overrides implementation of 'IWitOracleView' ------------------------------------------------------

    /// @notice Gets the whole Query data contents, if any, no matter its current status.
    /// @dev Fails if or if `msg.sender` is not the actual requester.
    function getQuery(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.Query memory)
    {
        return WitOracleTrustableBase.getQuery(_queryId);
    }

    /// @notice Retrieves the whole `Witnet.Response` record referred to a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not in 'Reported' status, or if `msg.sender` is not the actual requester.
    /// @param _queryId The unique query identifier
    function getQueryResponse(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.Response memory _response)
    {
        return WitOracleTrustableBase.getQueryResponse(_queryId);
    }

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    /// @param _queryId The unique query identifier.
    function getQueryResultError(uint256 _queryId)
        public view
        virtual override
        onlyRequester(_queryId)
        returns (Witnet.ResultError memory)
    {
        return WitOracleTrustableBase.getQueryResultError(_queryId);
    }
    
}
