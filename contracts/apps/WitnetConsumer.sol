// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../interfaces/V2/IWitnetConsumer.sol";

abstract contract WitnetConsumer
    is
        IWitnetConsumer,
        UsingWitnet
{    
    modifier burnQueryAfterReport(uint256 _witnetQueryId) {
        _;
        __witnet.burnQuery(_witnetQueryId);
    }
    
    modifier onlyFromWitnet {
        require(msg.sender == address(__witnet), "WitnetConsumer: unauthorized");
        _;
    }

    function _witnetEstimateBaseFee()
        virtual internal view 
        returns (uint256)
    {
        return _witnetEstimateBaseFeeWithCallback(_witnetReportCallbackMaxGas());
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward, 
            WitnetV2.RadonSLA calldata _witnetQuerySLA,
            bytes32 _witnetRadHash
        )
        virtual override internal
        returns (uint256)
    {
        return __witnet.postRequestWithCallback{value: _witnetEvmReward}(
            _witnetRadHash,
            _witnetQuerySLA
        );
    }

    function _witnetReportCallbackMaxGas() virtual internal view returns (uint256);
}
