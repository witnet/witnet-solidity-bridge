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
    
    constructor(
            WitnetRequest _witnetRequest, 
            uint96 _callbackGasLimit,
            WitnetV2.RadonSLA memory _defaultSLA
        )
        UsingWitnetRequest(_witnetRequest, _defaultSLA)
        WitnetConsumer(_callbackGasLimit)
    {
        require(
            _witnetEstimateBaseFeeWithCallback(_callbackGasLimit)
                > UsingWitnetRequest._witnetEstimateBaseFee(),
            "WitnetRequestConsumer: insufficient callback gas limit"
        );
    }

    function _witnetEstimateBaseFee() 
        virtual override
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateBaseFee(__witnetResultMaxSize);
    } 

    function _witnetEstimateBaseFee(uint16 _resultMaxSize)
        virtual override(UsingWitnet, WitnetConsumer)
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateBaseFee(_resultMaxSize);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA memory _witnetQuerySLA,
            bytes32 _witnetRadHash
        )
        virtual override(UsingWitnet, WitnetConsumer) internal
        returns (uint256)
    {
       return WitnetConsumer.__witnetRequestData(
            _witnetEvmReward,
            _witnetQuerySLA,
            _witnetRadHash
       );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA memory _witnetQuerySLA
        )
        virtual override internal
        returns (uint256)
    {
        return WitnetConsumer.__witnetRequestData(
            _witnetEvmReward,
            _witnetQuerySLA,
            __witnetRequestRadHash
        );
    }

}
