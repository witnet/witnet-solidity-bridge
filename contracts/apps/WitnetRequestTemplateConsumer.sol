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
    /// @param _defaultSLA Default Security-Level Agreement parameters to be fulfilled by the Witnet blockchain.
    constructor(
            WitnetRequestTemplate _witnetRequestTemplate, 
            uint16 _baseFeeOverheadPercentage,
            uint96 _callbackGasLimit,
            WitnetV2.RadonSLA memory _defaultSLA
        )
        UsingWitnetRequestTemplate(_witnetRequestTemplate, _baseFeeOverheadPercentage, _defaultSLA)
        WitnetConsumer(_callbackGasLimit)
    {}

    function _witnetEstimateEvmReward()
        virtual override(UsingWitnetRequestTemplate, WitnetConsumer)
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateEvmReward(__witnetResultMaxSize);
    }

    function _witnetEstimateEvmReward(uint16) 
        virtual override(UsingWitnet, WitnetConsumer) 
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateEvmReward();
    } 

}
