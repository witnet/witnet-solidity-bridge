// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../WitnetRequest.sol";

abstract contract UsingWitnetRequest
    is UsingWitnet
{
    WitnetRequest immutable public dataRequest;
    
    bytes32 immutable internal __witnetRequestRadHash;
    uint16  immutable internal __witnetQueryResultMaxSize;
 
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
        __witnetQueryResultMaxSize = _witnetRequest.resultDataMaxSize();
        __witnetRequestRadHash = _witnetRequest.radHash();
        __witnetSetBaseFeeOverheadPercentage(_baseFeeOverheadPercentage);
    }

    function _witnetEstimateEvmReward()
        virtual internal view
        returns (uint256)
    {
        return _witnetEstimateEvmReward(__witnetQueryResultMaxSize);
    }

    function __witnetRequestData(uint256 _witnetEvmReward)
        virtual internal returns (uint256)
    {
        return __witnetRequestData(_witnetEvmReward, __witnetDefaultSLA);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA memory _witnetQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            __witnetRequestRadHash,
            _witnetQuerySLA
        );
    }
}
