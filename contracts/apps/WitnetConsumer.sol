// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../interfaces/IWitnetConsumer.sol";

abstract contract WitnetConsumer
    is
        IWitnetConsumer,
        UsingWitnet
{ 
    /// @dev Maximum gas to be spent by the IWitnetConsumer's callback methods.  
    uint24 internal immutable __witnetCallbackGasLimit;
  
    modifier onlyFromWitnet {
        require(msg.sender == address(__witnet), "WitnetConsumer: unauthorized");
        _;
    }

    /// @param _callbackGasLimit Maximum gas to be spent by the IWitnetConsumer's callback methods.
    constructor (uint24 _callbackGasLimit) {
        __witnetCallbackGasLimit = _callbackGasLimit;
    }

    
    /// ===============================================================================================================
    /// --- Base implementation of IWitnetConsumer --------------------------------------------------------------------

    function reportableFrom(address _from) virtual override external view returns (bool) {
        return _from == address(__witnet);
    }


    /// ===============================================================================================================
    /// --- WitnetConsumer virtual methods ----------------------------------------------------------------------------

    function _witnetEstimateEvmReward() virtual internal view returns (uint256) {
        return (
            (100 + __witnetBaseFeeOverheadPercentage)
                * __witnet.estimateBaseFeeWithCallback(
                    tx.gasprice,
                    __witnetCallbackGasLimit
                )
        ) / 100;
    }
    
    function _witnetEstimateEvmReward(uint16)
        virtual override internal view
        returns (uint256)
    {
        return _witnetEstimateEvmReward();
    }


    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function _witnetEstimateEvmRewardWithCallback(uint24 _callbackGasLimit)
        virtual internal view
        returns (uint256)
    {
        return (
            (100 + __witnetBaseFeeOverheadPercentage)
                * __witnet.estimateBaseFeeWithCallback(
                    tx.gasprice, 
                    _callbackGasLimit
                )
        ) / 100;
    }
}
