// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracleRequest.sol";
import "./WitOracleConsumer.sol";

abstract contract WitOracleRequestConsumer
    is
        UsingWitOracleRequest,
        WitOracleConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];

    /// @param _witOracleRequest Address of the WitOracleRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor(
            WitOracleRequest _witOracleRequest, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitOracleRequest(_witOracleRequest, _baseFeeOverheadPercentage)
        WitOracleConsumer(_callbackGasLimit)
    {}

    /// @dev Estimate the minimum reward required for posting a data request (based on given gas price and 
    /// @dev immutable `__witOracleCallbackGasLimit`).
    function _witOracleEstimateBaseFee(uint256 _evmGasPrice)
        virtual override (UsingWitOracle, WitOracleConsumer)
        internal view 
        returns (uint256)
    {
        return WitOracleConsumer._witOracleEstimateBaseFee(_evmGasPrice);
    }

    /// @dev Pulls a data update from the Wit/oracle blockchain based on the underlying `witOracleRequest`,
    /// @dev the default `__witOracleDefaultQuerySLA` data security parameters and the immutable value of
    /// @dev `__witOracleCalbackGasLimit`.
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle when pulling the data update.
    function __witOraclePostQuery(
            uint256 _queryEvmReward
        )
        virtual override internal returns (uint256)
    {
        return __witOraclePostQuery(
            _queryEvmReward,
            __witOracleDefaultQuerySLA
        );
    }

    /// @dev Pulls a data update from the Wit/oracle blockchain based on the underlying `witOracleRequest`,
    /// @dev the given `_querySLA` data security parameters and the immutable value of  `__witOracleCallbackGasLimit`. 
    /// @param _queryEvmReward The exact EVM reward passed to the WitOracle when pulling the data update.
    /// @param _querySLA The required SLA data security params for the Wit/oracle blockchain to accomplish.
    function __witOraclePostQuery(
            uint256 _queryEvmReward, 
            Witnet.RadonSLA memory _querySLA
        )
        virtual override internal returns (uint256)
    {
        return __witOracle.postQueryWithCallback{
            value: _queryEvmReward
        }(
            __witOracleRequestRadHash,
            _querySLA,
            __witOracleCallbackGasLimit
        );
    }
}
