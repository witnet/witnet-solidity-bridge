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
    
    constructor(WitnetRequestTemplate _requestTemplate, uint256 _maxCallbackGas)
        UsingWitnetRequestTemplate(_requestTemplate)
        WitnetConsumer(_maxCallbackGas)
    {
        require(
            _witnetEstimateBaseFeeWithCallback(_requestTemplate.resultDataMaxSize(), _maxCallbackGas)
                > UsingWitnetRequestTemplate._witnetEstimateBaseFee(),
            "WitnetRequestTemplateConsumer: callback gas limit too low"
        );

    }

    function _witnetEstimateBaseFee()
        virtual override
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateBaseFee(__witnetResultMaxSize);
    }

    function _witnetEstimateBaseFee(uint256 _resultMaxSize) 
        virtual override(UsingWitnet, WitnetConsumer) 
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateBaseFee(_resultMaxSize);
    } 

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            bytes32 _witnetRadHash,
            WitnetV2.RadonSLA memory _witnetQuerySLA
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

}
