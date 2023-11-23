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
    
    constructor(WitnetRequest _witnetRequest, uint256 _maxCallbackGas)
        UsingWitnetRequest(_witnetRequest)
        WitnetConsumer(_maxCallbackGas)
    {
        require(
            _witnetEstimateBaseFeeWithCallback(_maxCallbackGas) > UsingWitnetRequest._witnetEstimateBaseFee(),
            "WitnetRequestConsumer: max callback gas too low"
        );
    }

    function _witnetEstimateBaseFee() 
        virtual override(UsingWitnetRequest, WitnetConsumer) 
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateBaseFee();
    } 

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            bytes32 _witnetRadHash,
            WitnetV2.RadonSLA calldata _witnetQuerySLA
        )
        virtual override(UsingWitnet, WitnetConsumer) internal
        returns (uint256)
    {
       return WitnetConsumer.__witnetRequestData(
            _witnetEvmReward,
            _witnetRadHash,
            _witnetQuerySLA
       );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            bytes calldata _witnetRadBytecode,
            WitnetV2.RadonSLA calldata _witnetQuerySLA
        )
        virtual override(UsingWitnet, WitnetConsumer) internal
        returns (uint256)
    {
        return WitnetConsumer.__witnetRequestData(
            _witnetEvmReward,
            _witnetRadBytecode,
            _witnetQuerySLA
        );
    }
}
