// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../WitnetRequest.sol";

abstract contract UsingWitnetRequest
    is UsingWitnet
{
    WitnetRequest immutable public dataRequest;
    
    bytes32 immutable internal __witnetRequestRadHash;
    uint256 immutable internal __witnetResultMaxSize;
 
    constructor (WitnetRequest _witnetRequest)
        UsingWitnet(_witnetRequest.witnet())
    {
        require(
            _witnetRequest.class() == type(WitnetRequest).interfaceId,
            "UsingWitnetRequest: uncompliant WitnetRequest"
        );
        dataRequest = _witnetRequest;
        __witnetResultMaxSize = _witnetRequest.resultDataMaxSize();
        __witnetRequestRadHash = _witnetRequest.radHash();
    }

    function _witnetEstimateBaseFee()
        virtual internal view
        returns (uint256)
    {
        return __witnet.estimateBaseFee(
            tx.gasprice,
            __witnetResultMaxSize
        );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA calldata _witnetQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witnetRequestData(
            _witnetEvmReward,
            __witnetRequestRadHash,
            _witnetQuerySLA
        );
    }

}