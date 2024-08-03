// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnetRequestTemplate.sol";
import "./WitnetConsumer.sol";

abstract contract WitnetRequestTemplateConsumer
    is
        UsingWitnetRequestTemplate,
        WitnetConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];
    
    /// @param _witnetRequestTemplate Address of the WitnetRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitnetConsumer's callback methods.
    constructor(
            WitnetRequestTemplate _witnetRequestTemplate, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitnetRequestTemplate(_witnetRequestTemplate, _baseFeeOverheadPercentage)
        WitnetConsumer(_callbackGasLimit)
    {}

    function _witnetEstimateBaseFee()
        virtual override(UsingWitnet, WitnetConsumer)
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateBaseFee();
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
