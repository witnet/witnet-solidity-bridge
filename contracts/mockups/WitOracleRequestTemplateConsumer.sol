// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracleRequestTemplate.sol";
import "./WitOracleConsumer.sol";

abstract contract WitOracleRequestTemplateConsumer
    is
        UsingWitOracleRequestTemplate,
        WitOracleConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];
    
    /// @param _witOracleRequestTemplate Address of the WitOracleRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor(
            WitOracleRequestTemplate _witOracleRequestTemplate, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitOracleRequestTemplate(_witOracleRequestTemplate, _baseFeeOverheadPercentage)
        WitOracleConsumer(_callbackGasLimit)
    {}

    function _witOracleEstimateBaseFee()
        virtual override(UsingWitOracle, WitOracleConsumer)
        internal view
        returns (uint256)
    {
        return WitOracleConsumer._witOracleEstimateBaseFee();
    }

    function __witOracleRequestData(
            uint256 _witOracleEvmReward,
            string[][] memory _witOracleRequestArgs,
            Witnet.RadonSLA memory _witOracleQuerySLA
        )
        virtual override
        internal returns (uint256)
    {
        return __witOracle.postRequestWithCallback{
            value: _witOracleEvmReward
        }(
            _witOracleBuildRadHash(_witOracleRequestArgs),
            _witOracleQuerySLA,
            __witOracleCallbackGasLimit
        );
    }

}
