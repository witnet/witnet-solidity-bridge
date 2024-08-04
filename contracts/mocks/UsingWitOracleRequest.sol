// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";
import "../WitOracleRequest.sol";

abstract contract UsingWitOracleRequest
    is UsingWitOracle
{
    WitOracleRequest immutable public dataRequest;
    
    bytes32 immutable internal __witnetRequestRadHash;
 
    /// @param _witnetRequest Address of the WitOracleRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    constructor (
            WitOracleRequest _witnetRequest,
            uint16 _baseFeeOverheadPercentage
        )
        UsingWitOracle(_witnetRequest.witnet())
    {
        require(
            _witnetRequest.specs() == type(WitOracleRequest).interfaceId,
            "UsingWitOracleRequest: uncompliant WitOracleRequest"
        );
        dataRequest = _witnetRequest;
        __witnetRequestRadHash = _witnetRequest.radHash();
        __witnetBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
    }

    function __witnetRequestData(uint256 _witnetEvmReward)
        virtual internal returns (uint256)
    {
        return __witnetRequestData(_witnetEvmReward, __witnetDefaultSLA);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            Witnet.RadonSLA memory _witnetQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            __witnetRequestRadHash,
            _witnetQuerySLA
        );
    }
}
