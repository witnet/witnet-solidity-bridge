// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../interfaces/V2/IWitnetConsumer.sol";

abstract contract WitnetConsumer
    is
        IWitnetConsumer,
        UsingWitnet
{ 
    /// @dev Maximum gas to be spent by the IWitnetConsumer's callback methods.  
    uint96 private immutable __witnetCallbackGasLimit;
  
    modifier onlyFromWitnet {
        require(msg.sender == address(__witnet), "WitnetConsumer: unauthorized");
        _;
    }

    /// @param _callbackGasLimit Maximum gas to be spent by the IWitnetConsumer's callback methods.
    constructor (uint96 _callbackGasLimit) {
        __witnetCallbackGasLimit = _callbackGasLimit;
    }

    
    /// ===============================================================================================================
    /// --- Base implementation of IWitnetConsumer --------------------------------------------------------------------

    function reportableFrom(address _from) virtual override external view returns (bool) {
        return _from == address(__witnet);
    }


    /// ===============================================================================================================
    /// --- WitnetConsumer virtual methods ----------------------------------------------------------------------------

    function _witnetCallbackGasLimit()
        virtual internal view 
        returns (uint96)
    {
        return __witnetCallbackGasLimit;
    }

    function _witnetEstimateEvmReward() virtual internal view returns (uint256) {
        return (
            (100 + _witnetBaseFeeOverheadPercentage())
                * __witnet.estimateBaseFeeWithCallback(
                    tx.gasprice,
                    _witnetCallbackGasLimit()
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
    function _witnetEstimateEvmRewardWithCallback(uint96 _callbackGasLimit)
        virtual internal view
        returns (uint256)
    {
        return __witnet.estimateBaseFeeWithCallback(tx.gasprice, _callbackGasLimit);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward, 
            WitnetV2.RadonSLA memory _witnetQuerySLA,
            bytes32 _witnetRadHash
        )
        virtual override internal
        returns (uint256)
    {
        return __witnet.postRequestWithCallback{value: _witnetEvmReward}(
            _witnetRadHash,
            _witnetQuerySLA,
            __witnetCallbackGasLimit
        );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward, 
            WitnetV2.RadonSLA memory _witnetQuerySLA,
            bytes calldata _witnetRequestBytecode
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequestWithCallback{value: _witnetEvmReward}(
            _witnetRequestBytecode, 
            _witnetQuerySLA,
            __witnetCallbackGasLimit
        );
    }

}
