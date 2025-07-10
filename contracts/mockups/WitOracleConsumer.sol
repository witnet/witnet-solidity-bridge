// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IWitAppliance.sol";
import "../interfaces/IWitOracleConsumer.sol";
import "../interfaces/IWitOracleQueriable.sol";

abstract contract WitOracleConsumer
    is
        IWitOracleConsumer
{
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.QuerySLA;

    IWitOracle public immutable witOracle;
    IWitOracleRadonRegistry public immutable witOracleRadonRegistry;

    error InvalidDataResult();
    error InvalidQueryParams();
    error InvalidRadonHash();
 
    constructor (address _witOracle) {
        require(
            _witOracle.code.length > 0,
            "inexistent wit/oracle"
        );
        bytes4 _witOracleSpecs = IWitAppliance(address(_witOracle)).specs();
        require(
            _witOracleSpecs == type(IWitOracle).interfaceId 
                || _witOracleSpecs == type(IWitOracle).interfaceId ^ type(IWitOracleQueriable).interfaceId,
            "uncompliant wit/oracle"
        );
        witOracle = IWitOracle(_witOracle);
        witOracleRadonRegistry = IWitOracleRadonRegistry(IWitOracle(_witOracle).registry());
        require(
            address(witOracleRadonRegistry) == address(0)
                || IWitAppliance(address(witOracleRadonRegistry)).specs() == type(IWitOracleRadonRegistry).interfaceId,
            "uncompliant wit/registry"
        );
    }

    function pushDataReport(
            Witnet.DataPushReport calldata report, 
            bytes calldata proof
        )
        virtual override
        public
    {
        _witOraclePushDataResult(
            _validateDataReport(
                report,
                proof
            ),
            report.queryRadHash
        );
    }

    function _validateDataReport(
            Witnet.DataPushReport calldata report,
            bytes calldata proof
        )
        private
        returns (Witnet.DataResult memory)
    {
        require(_witOracleCheckQueryParams(report.queryParams), InvalidQueryParams());
        require(_witOracleCheckRadonHashIsValid(report.queryRadHash), InvalidRadonHash());
        return witOracle.pushDataReport(report, proof);
    }

    function _witOracleCheckQueryParams(Witnet.QuerySLA calldata) virtual internal view returns (bool);
    function _witOracleCheckRadonHashIsValid(Witnet.RadonHash witRadonHash) virtual internal view returns (bool);
    function _witOraclePushDataResult(Witnet.DataResult memory result, Witnet.RadonHash radonHash) virtual internal;
}
