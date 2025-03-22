// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./UsingWitOracleRequestTemplate.sol";
import "./WitOracleQueriableConsumer.sol";

abstract contract WitOracleQueriableRequestTemplateConsumer
    is
        UsingWitOracleRequestTemplate,
        WitOracleQueriableConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];
    
    /// @param _witOracleRequestTemplate Address of the WitOracleRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGas Maximum gas to be spent by the IWitOracleQueriableConsumer's callback methods.
    constructor(
            WitOracleRequestTemplate _witOracleRequestTemplate, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGas
        )
        UsingWitOracleRequestTemplate(_witOracleRequestTemplate, _baseFeeOverheadPercentage)
        WitOracleQueriableConsumer(_callbackGas)
    {}

    /// @dev Estimate the minimum reward required for posting a data request (based on given gas price and 
    /// @dev immutable `__witOracleCallbackGasLimit`).
    function _witOracleEstimateBaseFee(uint256 _evmGasPrice)
        virtual override (UsingWitOracle, WitOracleQueriableConsumer)
        internal view 
        returns (uint256)
    {
        return WitOracleQueriableConsumer._witOracleEstimateBaseFee(_evmGasPrice);
    }

    /// @dev Pulls a fresh update from the Wit/Oracle blockchain based on some data request built out
    /// @dev of the underlying `witOracleRequestTemplate`, the default `__witOracleDefaultQueryParams` data
    /// @dev security parameters and the immutable value of `__witOracleCallbackGasLimit`.
    /// @dev Returns the unique RAD hash of the just-built data request, and some unique query id. 
    /// @dev Reverts if the number of given parameters don't match as required by the underlying template's 
    /// @dev parameterized data sources (i.e. Radon Retrievals). 
    /// @param _witOracleRequestArgs Parameters passed to the `witOracleRequestTemplate` for building a new data request.
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle bridge when pulling the data update.
    function __witOracleQueryData(
            string[][] memory _witOracleRequestArgs,
            uint256 _queryEvmReward
        )
        virtual override internal returns (Witnet.RadonHash, Witnet.QueryId)
    {
        return __witOracleQueryData(
            _witOracleRequestArgs,
            _queryEvmReward, 
            __witOracleDefaultQueryParams
        );
    }

    /// @dev Pulls a fresh update from the Wit/Oracle blockchain based on some data request built out
    /// @dev of the underlying `witOracleRequestTemplate`, and the given `_querSLA` data security parameters,
    /// @dev and the immutable value of `__witOracleCallbackGasLimit`. 
    /// @dev Returns the unique RAD hash of the just-built data request, and some unique query id. 
    /// @dev Reverts if the number of given parameters don't match as required by the underlying template's 
    /// @dev parameterized data sources (i.e. Radon Retrievals). 
    /// @param _witOracleRequestArgs Parameters passed to the `witOracleRequestTemplate` for building a new data request.
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle bridge when pulling the data update.
    /// @param _querySLA The required SLA data security params for the Wit/Oracle blockchain to accomplish.
    function __witOracleQueryData(
            string[][] memory _witOracleRequestArgs,
            uint256 _queryEvmReward,
            Witnet.QuerySLA memory _querySLA
        )
        virtual override internal
        returns (
            Witnet.RadonHash _queryRadHash, 
            Witnet.QueryId _queryId
        )
    {
        _queryRadHash = __witOracleVerifyRadonRequest(_witOracleRequestArgs);
        _queryId = __witOracle.queryDataWithCallback{
            value: _queryEvmReward
        }(
            _queryRadHash,
            _querySLA,
            Witnet.QueryCallback({
                consumer: address(this),
                gasLimit: __witOracleCallbackGasLimit
            })
        );
    }
}
