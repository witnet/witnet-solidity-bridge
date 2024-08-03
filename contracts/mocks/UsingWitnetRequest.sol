// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../WitnetRequest.sol";

abstract contract UsingWitnetRequest
    is UsingWitnet
{
    WitnetRequest immutable public dataRequest;
    
    bytes32 immutable internal __witnetRequestRadHash;
 
    /// @param _witnetRequest Address of the WitnetRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    constructor (
            WitnetRequest _witnetRequest,
            uint16 _baseFeeOverheadPercentage
        )
        UsingWitnet(_witnetRequest.witnet())
    {
        require(
            _witnetRequest.specs() == type(WitnetRequest).interfaceId,
            "UsingWitnetRequest: uncompliant WitnetRequest"
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
