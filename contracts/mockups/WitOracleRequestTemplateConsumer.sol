// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracleRequestTemplate.sol";
import "./WitConsumer.sol";

abstract contract WitOracleRequestTemplateConsumer
    is
        UsingWitOracleRequestTemplate,
        WitConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];
    
    /// @param _witnetRequestTemplate Address of the WitOracleRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor(
            WitOracleRequestTemplate _witnetRequestTemplate, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitOracleRequestTemplate(_witnetRequestTemplate, _baseFeeOverheadPercentage)
        WitConsumer(_callbackGasLimit)
    {}

    function _witnetEstimateBaseFee()
        virtual override(UsingWitOracle, WitConsumer)
        internal view
        returns (uint256)
    {
        return WitConsumer._witnetEstimateBaseFee();
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            string[][] memory _witnetRequestArgs,
            Witnet.RadonSLA memory _witnetQuerySLA
        )
        virtual override
        internal returns (uint256)
    {
        return __witnet.postRequestWithCallback{
            value: _witnetEvmReward
        }(
            _witnetBuildRadHash(_witnetRequestArgs),
            _witnetQuerySLA,
            __witnetCallbackGasLimit
        );
    }

}
