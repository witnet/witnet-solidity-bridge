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

    uint256 private immutable __witnetReportCallbackMaxGas;
    
    constructor(WitnetRequestTemplate _requestTemplate, uint256 _maxCallbackGas)
        UsingWitnetRequestTemplate(_requestTemplate)
    {
        require(
            _witnetEstimateBaseFeeWithCallback(_maxCallbackGas) > UsingWitnetRequestTemplate._witnetEstimateBaseFee(),
            "WitnetRequestTemplateConsumer: max callback gas too low"
        );
        __witnetReportCallbackMaxGas = _maxCallbackGas;
    }

    function _witnetEstimateBaseFee() 
        virtual override(UsingWitnetRequestTemplate, WitnetConsumer) 
        internal view
        returns (uint256)
    {
        return WitnetConsumer._witnetEstimateBaseFee();
    } 

    function _witnetReportCallbackMaxGas() virtual override internal view returns (uint256) {
        return __witnetReportCallbackMaxGas;
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA calldata _witnetQuerySLA,
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

    function reportWitnetQueryResult(
            uint256 _witnetQueryId, 
            WitnetCBOR.CBOR calldata _value
        )
        virtual override 
        external
        onlyFromWitnet
        // optional: burnQueryAfterReport(_witnetQueryId)
    {
        // TODO ...
    }

    function reportWitnetQueryError(
            uint256 _witnetQueryId,
            Witnet.ResultErrorCodes,
            uint256
        )
        virtual override external
        onlyFromWitnet
        // optional: burnQueryAfterReport(_witnetQueryId)
    {
        // TODO ...
    }
}
