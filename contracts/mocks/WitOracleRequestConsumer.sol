// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracleRequest.sol";
import "./WitConsumer.sol";

abstract contract WitOracleRequestConsumer
    is
        UsingWitOracleRequest,
        WitConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];

    /// @param _witnetRequest Address of the WitOracleRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor(
            WitOracleRequest _witnetRequest, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitOracleRequest(_witnetRequest, _baseFeeOverheadPercentage)
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
            Witnet.RadonSLA memory _witnetQuerySLA
        )
        virtual override
        internal returns (uint256)
    {
        return __witnet.postRequestWithCallback{
            value: _witnetEvmReward
        }(
            __witnetRequestRadHash,
            _witnetQuerySLA,
            __witnetCallbackGasLimit
        );
    }
}
