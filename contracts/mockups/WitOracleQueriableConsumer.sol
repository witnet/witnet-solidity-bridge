// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./UsingWitOracle.sol";
import "../interfaces/IWitOracleQueriableConsumer.sol";

abstract contract WitOracleQueriableConsumer
    is
        IWitOracleQueriableConsumer,
        UsingWitOracle
{ 
    /// @dev Maximum gas to be spent by the IWitOracleQueriableConsumer's callback methods.  
    uint24 internal immutable __witOracleCallbackGasLimit;
  
    modifier onlyFromWitOracle {
        require(msg.sender == address(__witOracle), "WitOracleQueriableConsumer: unauthorized");
        _;
    }

    /// @param _callbackGas Maximum gas to be spent by the IWitOracleQueriableConsumer's callback methods.
    constructor (uint24 _callbackGas) {
        __witOracleCallbackGasLimit = _callbackGas;
    }

    
    /// ===============================================================================================================
    /// --- Base implementation of IWitOracleQueriableConsumer --------------------------------------------------------------------

    function reportableFrom(IWitOracleQueriable _from) virtual override external view returns (bool) {
        return address(_from) == address(__witOracle);
    }


    /// ===============================================================================================================
    /// --- WitOracleQueriableConsumer virtual methods ----------------------------------------------------------------------------

    /// @dev Estimate the minimum reward required for posting a data request (based on given gas price and 
    /// @dev immutable `__witOracleCallbackGasLimit`).
    function _witOracleEstimateBaseFee(uint256 _evmGasPrice)
        virtual override 
        internal view 
        returns (uint256)
    {
        return (
            (100 + __witOracleBaseFeeOverheadPercentage)
                * __witOracle.estimateBaseFeeWithCallback(
                    _evmGasPrice, 
                    __witOracleCallbackGasLimit
                )
        ) / 100;
    }
}
