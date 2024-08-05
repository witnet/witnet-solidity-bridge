// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";

import "../WitOracleRequest.sol";
import "../WitOracleRequestTemplate.sol";

abstract contract UsingWitOracleRequestTemplate
    is UsingWitOracle
{
    WitOracleRequestTemplate immutable public dataRequestTemplate;
 
    /// @param _witOracleRequestTemplate Address of the WitOracleRequestTemplate from which actual data requests will get built.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    constructor (
            WitOracleRequestTemplate _witOracleRequestTemplate,
            uint16 _baseFeeOverheadPercentage
        )
        UsingWitOracle(_witOracleRequestTemplate.witOracle())
    {
        require(
            _witOracleRequestTemplate.specs() == type(WitOracleRequestTemplate).interfaceId,
            "UsingWitOracleRequestTemplate: uncompliant WitOracleRequestTemplate"
        );
        dataRequestTemplate = _witOracleRequestTemplate;
        __witOracleBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    function _witOracleBuildRadHash(string[][] memory _witOracleRequestArgs)
        internal returns (bytes32)
    {
        return dataRequestTemplate.verifyRadonRequest(_witOracleRequestArgs);
    }
    
    function _witOracleBuildRequest(string[][] memory _witOracleRequestArgs)
        internal returns (WitOracleRequest)
    {
        return WitOracleRequest(dataRequestTemplate.buildWitOracleRequest(_witOracleRequestArgs));
    }

    function __witOracleRequestData(
            uint256 _witOracleEvmReward,
            string[][] memory _witOracleRequestArgs
        )
        virtual internal returns (uint256)
    {
        return __witOracleRequestData(_witOracleEvmReward, _witOracleRequestArgs, __witOracleDefaultSLA);
    }

    function __witOracleRequestData(
            uint256 _witOracleEvmReward,
            string[][] memory _witOracleRequestArgs,
            Witnet.RadonSLA memory _witOracleQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witOracle.postRequest{value: _witOracleEvmReward}(
            _witOracleBuildRadHash(_witOracleRequestArgs),
            _witOracleQuerySLA
        );
    }
}
