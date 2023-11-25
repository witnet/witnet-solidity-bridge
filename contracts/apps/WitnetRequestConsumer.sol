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
            _witnetEstimateBaseFeeWithCallback(_witnetRequest.resultDataMaxSize(), _maxCallbackGas)
                > UsingWitnetRequest._witnetEstimateBaseFee(),
            "WitnetRequestConsumer: callback gas limit too low"
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
