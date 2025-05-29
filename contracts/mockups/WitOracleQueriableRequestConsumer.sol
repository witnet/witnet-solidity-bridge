// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./UsingWitOracleRequest.sol";
import "./WitOracleQueriableConsumer.sol";

abstract contract WitOracleQueriableRequestConsumer
    is
        UsingWitOracleRequest,
        WitOracleQueriableConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];

    /// @param _witOracleRequest Address of the WitOracleRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGas Maximum gas to be spent by the IWitOracleQueriableConsumer's callback methods.
    constructor(
            WitOracleRequest _witOracleRequest, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGas
        )
        UsingWitOracleRequest(_witOracleRequest, _baseFeeOverheadPercentage)
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

    /// @dev Pulls a data update from the Wit/Oracle blockchain based on the underlying `witOracleRequest`,
    /// @dev the default `__witOracleDefaultQueryParams` data security parameters and the immutable value of
    /// @dev `__witOracleCalbackGasLimit`.
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle when pulling the data update.
    function __witOracleQueryData(
            uint256 _queryEvmReward
        )
        virtual override internal returns (uint256)
    {
        return __witOracleQueryData(
            _queryEvmReward,
            __witOracleDefaultQueryParams
        );
    }

    /// @dev Pulls a data update from the Wit/Oracle blockchain based on the underlying `witOracleRequest`,
    /// @dev the given `_querySLA` data security parameters and the immutable value of  `__witOracleCallbackGasLimit`. 
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle when pulling the data update.
    /// @param _querySLA The required SLA data security params for the Wit/Oracle blockchain to accomplish.
    function __witOracleQueryData(
            uint256 _queryEvmReward, 
            Witnet.QuerySLA memory _querySLA
        )
        virtual override internal returns (uint256)
    {
        return __witOracle.queryDataWithCallback{
            value: _queryEvmReward
        }(
            __wirOracleRequestHash,
            _querySLA,
            Witnet.QueryCallback({
                consumer: address(this),
                gasLimit: __witOracleCallbackGasLimit
            })
        );
    }
}
