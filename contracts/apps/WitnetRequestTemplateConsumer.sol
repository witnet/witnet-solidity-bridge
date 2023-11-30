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
    
    constructor(
            WitnetRequestTemplate _requestTemplate, 
            uint96 _callbackGasLimit,
            WitnetV2.RadonSLA memory _defaultSLA
        )
        UsingWitnetRequestTemplate(_requestTemplate, _defaultSLA)
        WitnetConsumer(_callbackGasLimit)
    {
        require(
            _witnetEstimateBaseFeeWithCallback(_callbackGasLimit)
                > UsingWitnetRequestTemplate._witnetEstimateBaseFee(),
            "WitnetRequestTemplateConsumer: insufficient callback gas limit"
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
            bytes32 _witnetRadHash
        )
        virtual override internal 
        returns (uint256)
    {
        return WitnetConsumer.__witnetRequestData(
            _witnetEvmReward,
            _witnetDefaultSLA(),
            _witnetRadHash
        );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA memory _witnetQuerySLA,
            string[][] memory _witnetRequestArgs
        )
        virtual override internal
        returns (uint256)
    {
        return WitnetConsumer.__witnetRequestData(
            _witnetEvmReward,
            _witnetQuerySLA,
            _witnetBuildRadHash(_witnetRequestArgs)
        );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            string[][] memory _witnetRequestArgs
        )
        virtual override internal
        returns (uint256)
    {
        return WitnetConsumer.__witnetRequestData(
            _witnetEvmReward,
            _witnetDefaultSLA(),
            _witnetBuildRadHash(_witnetRequestArgs)
        );
    }

}
