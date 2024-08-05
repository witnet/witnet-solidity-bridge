// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";
import "../interfaces/IWitOracleConsumer.sol";

abstract contract WitOracleConsumer
    is
        IWitOracleConsumer,
        UsingWitOracle
{ 
    /// @dev Maximum gas to be spent by the IWitOracleConsumer's callback methods.  
    uint24 internal immutable __witnetCallbackGasLimit;
  
    modifier onlyFromWitnet {
        require(msg.sender == address(__witnet), "WitOracleConsumer: unauthorized");
        _;
    }

    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor (uint24 _callbackGasLimit) {
        __witnetCallbackGasLimit = _callbackGasLimit;
    }

    
    /// ===============================================================================================================
    /// --- Base implementation of IWitOracleConsumer --------------------------------------------------------------------

    function reportableFrom(address _from) virtual override external view returns (bool) {
        return _from == address(__witnet);
    }


    /// ===============================================================================================================
    /// --- WitOracleConsumer virtual methods ----------------------------------------------------------------------------

    function _witnetEstimateBaseFee() virtual override internal view returns (uint256) {
        return (
            (100 + __witnetBaseFeeOverheadPercentage)
                * __witnet.estimateBaseFeeWithCallback(
                    tx.gasprice,
                    __witnetCallbackGasLimit
                )
        ) / 100;
    }


    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function _witnetEstimateBaseFeeWithCallback(uint24 _callbackGasLimit)
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
