// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../WitnetRequest.sol";

abstract contract UsingWitnetRequestTemplate
    is UsingWitnet
{
    WitnetRequestTemplate immutable public dataRequestTemplate;
    
    uint16 immutable internal __witnetResultMaxSize;
 
    /// @param _witnetRequestTemplate Address of the WitnetRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _defaultSLA Default Security-Level Agreement parameters to be fulfilled by the Witnet blockchain.
    constructor (
            WitnetRequestTemplate _witnetRequestTemplate, 
            uint16 _baseFeeOverheadPercentage,
            WitnetV2.RadonSLA memory _defaultSLA
        )
        UsingWitnet(_witnetRequestTemplate.witnet())
    {
        require(
            _witnetRequestTemplate.specs() == type(WitnetRequestTemplate).interfaceId,
            "UsingWitnetRequestTemplate: uncompliant WitnetRequestTemplate"
        );
        dataRequestTemplate = _witnetRequestTemplate;
        __witnetResultMaxSize = _witnetRequestTemplate.resultDataMaxSize();
        __witnetSetDefaultSLA(_defaultSLA);
        __witnetSetBaseFeeOverheadPercentage(_baseFeeOverheadPercentage);
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

    function _witnetEstimateEvmReward()
        virtual internal view
        returns (uint256)
    {
        return _witnetEstimateEvmReward(__witnetResultMaxSize);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            string[][] memory _witnetRequestArgs
        )
        virtual internal returns (uint256)
    {
        return __witnetRequestData(_witnetEvmReward, _witnetRequestArgs, _witnetDefaultSLA());
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            string[][] memory _witnetRequestArgs,
            WitnetV2.RadonSLA memory _witnetQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            _witnetBuildRadHash(_witnetRequestArgs),
            _witnetQuerySLA
        );
    }
}
