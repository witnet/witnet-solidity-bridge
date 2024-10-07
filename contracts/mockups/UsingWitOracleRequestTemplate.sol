// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";

import "../WitOracleRequest.sol";
import "../WitOracleRequestTemplate.sol";

abstract contract UsingWitOracleRequestTemplate
    is UsingWitOracle
{
    /// @notice Immutable address of the inderlying WitOracleRequestTemplate contained within this contract.
    WitOracleRequestTemplate immutable public witOracleRequestTemplate;
 
    /// @param _witOracleRequestTemplate Address of the WitOracleRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    constructor (
            WitOracleRequestTemplate _witOracleRequestTemplate,
            uint16 _baseFeeOverheadPercentage
        )
        UsingWitOracle(_witOracleRequestTemplate.witOracle())
    {
        require(
            _witOracleRequestTemplate.specs() == type(WitOracleRequestTemplate).interfaceId,
            "UsingWitOracleRequestTemplate: uncompliant WitOracleRequestTemplate"
        );
        witOracleRequestTemplate = _witOracleRequestTemplate;
        __witOracleBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    /// @dev Verify and register into the witOracle() registry a Wit/oracle compliant data request based
    /// @dev on the underlying `witOracleRequestTemplate`. Returns the RAD hash of the successfully verifed
    /// @dev data request. Reverts if the number of given parameters don't match as required by the underlying
    /// @dev template's parameterized data sources (i.e. Radon Retrievals).
    function __witOracleVerifyRadonRequest(
            string[][] memory _witOracleRequestArgs
        )
        virtual internal returns (bytes32)
    {
        return witOracleRequestTemplate.verifyRadonRequest(_witOracleRequestArgs);
    }

    /// @dev Pulls a fresh update from the Wit/oracle blockchain of some pre-verified Wit/oracle compliant 
    /// @dev data request, and the default `__witOracleDefaultQuerySLA` data security parameters.
    /// @dev Returns some unique query id. 
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle bridge when pulling the data update.
    /// @param _queryRadHash RAD hash of some pre-verified data request in the witOracle()'s registry. 
    function __witOraclePostQuery(
            uint256 _queryEvmReward, 
            bytes32 _queryRadHash
        )
        virtual internal returns (uint256)
    {
        return __witOraclePostQuery(
            _queryEvmReward,
            _queryRadHash,
            __witOracleDefaultQuerySLA
        );
    }

    /// @dev Pulls a fresh update from the Wit/oracle blockchain of some pre-verified Wit/oracle compliant 
    /// @dev data request, and the given `_querSLA` data security parameters. Returns some unique query id.
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle bridge when pulling the data update.
    /// @param _queryRadHash RAD hash of some pre-verified data request in the witOracle()'s registry. 
    /// @param _querySLA The required SLA data security params for the Wit/oracle blockchain to accomplish.
    function __witOraclePostQuery(
            uint256 _queryEvmReward, 
            bytes32 _queryRadHash, 
            Witnet.RadonSLA memory _querySLA
        )
        virtual internal returns (uint256)
    {
        return __witOracle.postQuery{
            value: _queryEvmReward
        }(
            _queryRadHash,
            _querySLA
        );
    }

    /// @dev Pulls a fresh update from the Wit/oracle blockchain based on some data request built out
    /// @dev of the underlying `witOracleRequestTemplate`, and the default `__witOracleDefaultQuerySLA` 
    /// @dev data security parameters. Returns the unique RAD hash of the just-built data request, and some 
    /// @dev unique query id. Reverts if the number of given parameters don't match as required by the 
    /// @dev underlying template's parameterized data sources (i.e. Radon Retrievals). 
    /// @param _witOracleRequestArgs Parameters passed to the `witOracleRequestTemplate` for building a new data request.
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle bridge when pulling the data update.
    function __witOraclePostQuery(
            string[][] memory _witOracleRequestArgs,
            uint256 _queryEvmReward
        )
        virtual internal returns (bytes32, uint256)
    {
        return __witOraclePostQuery(
            _witOracleRequestArgs,
            _queryEvmReward, 
            __witOracleDefaultQuerySLA
        );
    }

    /// @dev Pulls a fresh update from the Wit/oracle blockchain based on some data request built out
    /// @dev of the underlying `witOracleRequestTemplate`, and the given `_querSLA` data security parameters.
    /// @dev Returns the unique RAD hash of the just-built data request, and some unique query id. 
    /// @dev Reverts if the number of given parameters don't match as required by the underlying template's 
    /// @dev parameterized data sources (i.e. Radon Retrievals). 
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle bridge when pulling the data update.
    /// @param _querySLA The required SLA data security params for the Wit/oracle blockchain to accomplish.
    /// @param _witOracleRequestArgs Parameters passed to the `witOracleRequestTemplate` for building a new data request.
    function __witOraclePostQuery(
            string[][] memory _witOracleRequestArgs,
            uint256 _queryEvmReward,
            Witnet.RadonSLA memory _querySLA
        )
        virtual internal returns (
            bytes32 _queryRadHash,
            uint256 _queryId
        )
    {
        _queryRadHash = __witOracleVerifyRadonRequest(_witOracleRequestArgs);
        _queryId = __witOraclePostQuery(
            _queryEvmReward,
            _queryRadHash,
            _querySLA
        );
    }
}
