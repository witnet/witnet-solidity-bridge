// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitnet.sol";
import "../interfaces/V2/IWitnetConsumer.sol";

abstract contract WitnetConsumer
    is
        IWitnetConsumer,
        UsingWitnet
{   
    uint96 private immutable __witnetReportCallbackGasLimit;
  
    modifier onlyFromWitnet {
        require(msg.sender == address(__witnet), "WitnetConsumer: unauthorized");
        _;
    }

    constructor (uint96 _maxCallbackGas) {
        __witnetReportCallbackGasLimit = _maxCallbackGas;
    }

    
    /// ===============================================================================================================
    /// --- Base implementation of IWitnetConsumer --------------------------------------------------------------------

    function reportableFrom(address _from) virtual override external view returns (bool) {
        return _from == address(__witnet);
    }


    /// ===============================================================================================================
    /// --- WitnetConsumer virtual methods ----------------------------------------------------------------------------

    function _witnetEstimateBaseFee(uint16)
        virtual override internal view
        returns (uint256)
    {
        return _witnetEstimateBaseFeeWithCallback(_witnetReportCallbackGasLimit());
    }


    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function _witnetEstimateBaseFeeWithCallback(uint96 _callbackGasLimit)
        virtual internal view
        returns (uint256)
    {
        return __witnet.estimateBaseFeeWithCallback(tx.gasprice, _callbackGasLimit);
    }

    function _witnetReportCallbackGasLimit()
        virtual internal view 
        returns (uint96)
    {
        return __witnetReportCallbackGasLimit;
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
            __witnetReportCallbackGasLimit
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
            __witnetReportCallbackGasLimit
        );
    }

}
