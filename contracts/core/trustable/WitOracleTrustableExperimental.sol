// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseQueriableTrustable.sol";
import "../../interfaces/IWitOracleQueriableExperimental.sol";

/// @title WitOracle "experimental" implementation contract.
/// @author The Witnet Foundation
contract WitOracleTrustableExperimental
    is 
        IWitOracleQueriableExperimental,
        WitOracleBaseQueriableTrustable
{
    using WitOracleDataLib for WitOracleDataLib.Committee;

    function class() virtual override public view returns (string memory) {
        return type(WitOracleTrustableExperimental).name;
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
    // --- IWitOracleQueriableExperimental -------------------------------------------------------------------------------------

    function extractDelegatedDataRequest(Witnet.QueryId _queryId)
        virtual override public view
        returns (IWitOracleQueriableExperimental.DDR memory _dr)
    {
        Witnet.QueryStatus _queryStatus = getQueryStatus(_queryId);
        if (
            _queryStatus == Witnet.QueryStatus.Posted
                || _queryStatus == Witnet.QueryStatus.Delayed
        ) {
            _dr = WitOracleDataLib.extractDelegatedDataRequest(registry, _queryId);
        }
    }

    function extractDelegatedDataRequestBatch(Witnet.QueryId[] calldata _queryIds)
        virtual override external view
        returns (IWitOracleQueriableExperimental.DDR[] memory _drs)
    {
        _drs = new DDR[](_queryIds.length);
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            _drs[_ix] = extractDelegatedDataRequest(_queryIds[_ix]);
        }
    }

    /// @notice Enables data requesters to settle the actual validators in the Wit/Oracle
    /// @notice sidechain that will be entitled whatsover to solve 
    /// @notice data requests, as presumed to be capable of supporting some given `Wit2.Capability`.
    function settleMyOwnServiceCommittee(
            bytes32 _radonHash,
            Witnet.ServiceProvider[] calldata _providers
        )
        virtual override external
    {
        __storage().committees[msg.sender][Witnet.RadonHash.wrap(_radonHash)].settle(_providers);
        emit WitOracleServiceCommittee(
            msg.sender, 
            _radonHash, 
            _providers
        );
    }
}
