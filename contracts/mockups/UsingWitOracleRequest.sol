// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";
import "../WitOracleRequest.sol";

abstract contract UsingWitOracleRequest
    is UsingWitOracle
{
    /// @notice Immutable address of the underlying WitOracleRequest used for every fresh data
    /// @notice update pulled from this contract.
    WitOracleRequest immutable public witOracleRequest;
    
    /// @dev Immutable RAD hash of the underlying data request being solved on the Wit/Oracle blockchain
    /// @dev upon every fresh data update pulled from this contract.
    Witnet.RadonHash immutable internal __wirOracleRequestHash;
 
    /// @param _witOracleRequest Address of the WitOracleRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    constructor (
            WitOracleRequest _witOracleRequest,
            uint16 _baseFeeOverheadPercentage
        )
        UsingWitOracle(_witOracleRequest.witOracle())
    {
        require(
            _witOracleRequest.specs() == type(WitOracleRequest).interfaceId,
            "UsingWitOracleRequest: uncompliant WitOracleRequest"
        );
        witOracleRequest = _witOracleRequest;
        __wirOracleRequestHash = _witOracleRequest.radHash();
        __witOracleBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    /// @dev Pulls a data update from the Wit/Oracle blockchain based on the underlying `witOracleRequest`,
    /// @dev and the default `__witOracleDefaultQueryParams` data security parameters. 
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle when pulling the data update.
    function __witOracleQueryData(
            uint256 _queryEvmReward
        )
        virtual internal returns (uint256)
    {
        return __witOracleQueryData(
            _queryEvmReward, 
            __witOracleDefaultQueryParams
        );
    }

    /// @dev Pulls a data update from the Wit/Oracle blockchain based on the underlying `witOracleRequest`,
    /// @dev and the given `_querySLA` data security parameters. 
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle when pulling the data update.
    /// @param _querySLA The required SLA data security params for the Wit/Oracle blockchain to accomplish.
    function __witOracleQueryData(
            uint256 _queryEvmReward,
            Witnet.QuerySLA memory _querySLA
        )
        virtual internal returns (uint256)
    {
        return __witOracle.queryData{
            value: _queryEvmReward
        }(
            __wirOracleRequestHash,
            _querySLA
        );
    }
}
