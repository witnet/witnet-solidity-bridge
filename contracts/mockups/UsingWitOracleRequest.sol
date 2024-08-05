// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";
import "../WitOracleRequest.sol";

abstract contract UsingWitOracleRequest
    is UsingWitOracle
{
    WitOracleRequest immutable public dataRequest;
    
    bytes32 immutable internal __witOracleRequestRadHash;
 
    /// @param _witOracleRequest Address of the WitOracleRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    constructor (
            WitOracleRequest _witOracleRequest,
            uint16 _baseFeeOverheadPercentage
        )
        UsingWitOracle(_witOracleRequest.witOracle())
    {
        require(
            _witOracleRequest.specs() == type(WitOracleRequest).interfaceId,
            "UsingWitOracleRequest: uncompliant WitOracleRequest"
        );
        dataRequest = _witOracleRequest;
        __witOracleRequestRadHash = _witOracleRequest.radHash();
        __witOracleBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    function __witOracleRequestData(uint256 _witOracleEvmReward)
        virtual internal returns (uint256)
    {
        return __witOracleRequestData(_witOracleEvmReward, __witOracleDefaultSLA);
    }

    function __witOracleRequestData(
            uint256 _witOracleEvmReward,
            Witnet.RadonSLA memory _witOracleQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witOracle.postRequest{value: _witOracleEvmReward}(
            __witOracleRequestRadHash,
            _witOracleQuerySLA
        );
    }
}
