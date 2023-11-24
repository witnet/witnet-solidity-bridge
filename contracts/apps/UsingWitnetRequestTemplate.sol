// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../WitnetRequest.sol";

abstract contract UsingWitnetRequestTemplate
    is UsingWitnet
{
    WitnetRequestTemplate immutable public dataRequestTemplate;
    
    uint256 immutable internal __witnetResultMaxSize;
 
    constructor (WitnetRequestTemplate _requestTemplate)
        UsingWitnet(_requestTemplate.witnet())
    {
        require(
            _requestTemplate.specs() == type(WitnetRequestTemplate).interfaceId,
            "UsingWitnetRequestTemplate: uncompliant WitnetRequestTemplate"
        );
        dataRequestTemplate = _requestTemplate;
        __witnetResultMaxSize = _requestTemplate.resultDataMaxSize();
    }

    function _witnetBuildRadHash(string[][] memory _witnetRequestArgs)
        internal returns (bytes32)
    {
        return dataRequestTemplate.verifyRadonRequest(_witnetRequestArgs);
    }
    
    function _witnetBuildRequest(string[][] memory _witnetRequestArgs)
        internal returns (WitnetRequest)
    {
        return WitnetRequest(dataRequestTemplate.buildRequest(_witnetRequestArgs));
    }

    function _witnetEstimateBaseFee()
        virtual internal view
        returns (uint256)
    {
        return __witnet.estimateBaseFee(
            tx.gasprice,
            __witnetResultMaxSize
        );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA memory _witnetQuerySLA,
            string[][] memory _witnetRequestArgs
        )
        virtual internal returns (uint256)
    {
        return __witnetRequestData(
            _witnetEvmReward,
            _witnetBuildRadHash(_witnetRequestArgs),
            _witnetQuerySLA
        );
    }

}