// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnetRequest.sol";
import "./WitnetConsumer.sol";

abstract contract WitnetRequestConsumer
    is
        UsingWitnetRequest,
        WitnetConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];

    /// @param _witnetRequest Address of the WitnetRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitnetConsumer's callback methods.
    constructor(
            WitnetRequest _witnetRequest, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitnetRequest(_witnetRequest, _baseFeeOverheadPercentage)
        WitnetConsumer(_callbackGasLimit)
    {}

    function _witnetEstimateEvmReward() 
        virtual override(UsingWitnetRequest, WitnetConsumer)
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateEvmReward();
    } 

    function _witnetEstimateEvmReward(uint16)
        virtual override(UsingWitnet, WitnetConsumer)
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateEvmReward();
    }

}
