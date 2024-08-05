// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";

import "../WitOracleRequest.sol";
import "../WitOracleRequestTemplate.sol";

abstract contract UsingWitOracleRequestTemplate
    is UsingWitOracle
{
    WitOracleRequestTemplate immutable public dataRequestTemplate;
 
    /// @param _witnetRequestTemplate Address of the WitOracleRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    constructor (
            WitOracleRequestTemplate _witnetRequestTemplate,
            uint16 _baseFeeOverheadPercentage
        )
        UsingWitOracle(_witnetRequestTemplate.witnet())
    {
        require(
            _witnetRequestTemplate.specs() == type(WitOracleRequestTemplate).interfaceId,
            "UsingWitOracleRequestTemplate: uncompliant WitOracleRequestTemplate"
        );
        dataRequestTemplate = _witnetRequestTemplate;
        __witnetBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    function _witnetBuildRadHash(string[][] memory _witnetRequestArgs)
        internal returns (bytes32)
    {
        return dataRequestTemplate.verifyRadonRequest(_witnetRequestArgs);
    }
    
    function _witnetBuildRequest(string[][] memory _witnetRequestArgs)
        internal returns (WitOracleRequest)
    {
        return WitOracleRequest(dataRequestTemplate.buildWitOracleRequest(_witnetRequestArgs));
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            string[][] memory _witnetRequestArgs
        )
        virtual internal returns (uint256)
    {
        return __witnetRequestData(_witnetEvmReward, _witnetRequestArgs, __witnetDefaultSLA);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            string[][] memory _witnetRequestArgs,
            Witnet.RadonSLA memory _witOracleQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            _witnetBuildRadHash(_witnetRequestArgs),
            _witOracleQuerySLA
        );
    }
}
