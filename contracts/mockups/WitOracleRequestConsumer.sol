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

    function _witOracleEstimateBaseFee() 
        virtual override(UsingWitOracle, WitOracleConsumer)
        internal view
        returns (uint256)
    {
        return WitOracleConsumer._witOracleEstimateBaseFee();
    } 

    function __witOracleRequestData(
            uint256 _witOracleEvmReward, 
            Witnet.RadonSLA memory _witOracleQuerySLA
        )
        virtual override
        internal returns (uint256)
    {
        return __witOracle.postRequestWithCallback{
            value: _witOracleEvmReward
        }(
            __witOracleRequestRadHash,
            _witOracleQuerySLA,
            __witOracleCallbackGasLimit
        );
    }
}
