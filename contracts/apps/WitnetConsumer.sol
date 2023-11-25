// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../interfaces/V2/IWitnetConsumer.sol";

abstract contract WitnetConsumer
    is
        IWitnetConsumer,
        UsingWitnet
{   
    uint256 private immutable __witnetReportCallbackMaxGas;
  
    modifier onlyFromWitnet {
        require(msg.sender == address(__witnet), "WitnetConsumer: unauthorized");
        _;
    }

    constructor (uint256 _maxCallbackGas) {
        __witnetReportCallbackMaxGas = _maxCallbackGas;
    }

    
    /// ===============================================================================================================
    /// --- Base implementation of IWitnetConsumer --------------------------------------------------------------------

    function reportableFrom(address _from) virtual override external view returns (bool) {
        return _from == address(__witnet);
    }


    /// ===============================================================================================================
    /// --- WitnetConsumer virtual methods ----------------------------------------------------------------------------

    function _witnetEstimateBaseFee(uint256 _resultMaxSize)
        virtual override internal view
        returns (uint256)
    {
        return _witnetEstimateBaseFeeWithCallback(_resultMaxSize, _witnetReportCallbackMaxGas());
    }

    function _witnetReportCallbackMaxGas()
        virtual internal view 
        returns (uint256)
    {
        return __witnetReportCallbackMaxGas;
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward, 
            bytes32 _witnetRadHash,
            WitnetV2.RadonSLA memory _witnetQuerySLA
        )
        virtual override internal
        returns (uint256)
    {
        return __witnet.postRequestWithCallback{value: _witnetEvmReward}(
            _witnetRadHash,
            _witnetQuerySLA,
            __witnetReportCallbackMaxGas
        );
    }

}
