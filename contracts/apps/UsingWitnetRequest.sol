// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../WitnetRequest.sol";

abstract contract UsingWitnetRequest
    is UsingWitnet
{
    WitnetRequest immutable public dataRequest;
    
    bytes32 immutable internal __witnetRequestRadHash;
    uint16  immutable internal __witnetResultMaxSize;
 
    /// @param _witnetRequest Address of the WitnetRequest contract containing the actual data request.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _defaultSLA Default Security-Level Agreement parameters to be fulfilled by the Witnet blockchain.
    constructor (
            WitnetRequest _witnetRequest,
            uint16 _baseFeeOverheadPercentage,
            WitnetV2.RadonSLA memory _defaultSLA
        )
        UsingWitnet(_witnetRequest.witnet())
    {
        require(
            _witnetRequest.specs() == type(WitnetRequest).interfaceId,
            "UsingWitnetRequest: uncompliant WitnetRequest"
        );
        dataRequest = _witnetRequest;
        __witnetResultMaxSize = _witnetRequest.resultDataMaxSize();
        __witnetRequestRadHash = _witnetRequest.radHash();
        __witnetSetDefaultSLA(_defaultSLA);
        __witnetSetBaseFeeOverheadPercentage(_baseFeeOverheadPercentage);
    }

    function _witnetEstimateEvmReward()
        virtual internal view
        returns (uint256)
    {
        return _witnetEstimateEvmReward(__witnetResultMaxSize);
    }

    function __witnetRequestData(uint256 _witnetEvmReward)
        virtual internal returns (uint256)
    {
        return __witnetRequestData(_witnetEvmReward, _witnetDefaultSLA());
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
