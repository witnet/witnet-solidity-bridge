// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IWitOracleConsumer.sol";

abstract contract WitOracleConsumer
    is
        IWitOracleConsumer
{
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.QuerySLA;

    IWitOracle public immutable witOracle;
    IWitOracleRadonRegistry public immutable witOracleRadonRegistry;

    modifier witRadonHashIsKnown(Witnet.RadonHash witRadonHash) {
        require(
            _checkRadonHashExists(witRadonHash),
            "unknown radon hash"
        ); _;
    }
 
    constructor (IWitOracle _witOracle) {
        require(
            address(_witOracle) != address(0), 
            "inexistent oracle"
        );
        witOracle = IWitOracle(_witOracle);
        witOracleRadonRegistry = IWitOracleRadonRegistry(_witOracle.registry());
    }

    function pushDataReport(
            Witnet.DataPushReport calldata report, 
            bytes calldata proof
        )
        virtual override
        public
    {
        _processDataResult(
            _validateDataReport(
                report,
                proof
            )
        );
    }

    function _validateDataReport(
            Witnet.DataPushReport calldata report,
            bytes calldata proof
        )
        virtual internal
        returns (Witnet.DataResult memory)
    {
        require(
            _checkQueryParams(report.witDrSLA), 
            "invalid query params"
        );
        return witOracle.pushDataReport(report, proof);
    }

    function _checkRadonHashExists(Witnet.RadonHash witRadonHash) virtual internal view returns (bool) {
        return (
            address(witOracleRadonRegistry) == address(0) 
                || witOracleRadonRegistry.exists(witRadonHash)
        );
    }
    
    function _checkQueryParams(Witnet.QuerySLA calldata) virtual internal view returns (bool);
    function _processDataResult(Witnet.DataResult memory result) virtual internal;
}
