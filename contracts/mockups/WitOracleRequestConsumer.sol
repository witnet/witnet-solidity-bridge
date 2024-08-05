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

    /// @param _witnetRequest Address of the WitOracleRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor(
            WitOracleRequest _witnetRequest, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitOracleRequest(_witnetRequest, _baseFeeOverheadPercentage)
        WitOracleConsumer(_callbackGasLimit)
    {}

    function _witnetEstimateBaseFee() 
        virtual override(UsingWitOracle, WitOracleConsumer)
        internal view
        returns (uint256)
    {
        return WitOracleConsumer._witnetEstimateBaseFee();
    } 

    function __witnetRequestData(
            uint256 _witnetEvmReward, 
            Witnet.RadonSLA memory _witOracleQuerySLA
        )
        virtual override
        internal returns (uint256)
    {
        return __witnet.postRequestWithCallback{
            value: _witnetEvmReward
        }(
            __witnetRequestRadHash,
            _witOracleQuerySLA,
            __witnetCallbackGasLimit
        );
    }
}
