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

    uint256 private immutable __witnetReportCallbackMaxGas;
    
    constructor(WitnetRequest _witnetRequest, uint256 _maxCallbackGas)
        UsingWitnetRequest(_witnetRequest)
    {
        require(
            _witnetEstimateBaseFeeWithCallback(_maxCallbackGas) > UsingWitnetRequest._witnetEstimateBaseFee(),
            "WitnetRequestConsumer: max callback gas too low"
        );
        __witnetReportCallbackMaxGas = _maxCallbackGas;
    }

    function _witnetEstimateBaseFee() 
        virtual override(UsingWitnetRequest, WitnetConsumer) 
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
