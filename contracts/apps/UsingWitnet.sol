// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetOracle.sol";

/// @title The UsingWitnet contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitnet
    is
        IWitnetOracleEvents
{
    /// @dev Immutable reference to the Witnet Request Board contract.
    WitnetOracle internal immutable __witnet;
    
    /// @dev Default Security-Level Agreement parameters to be fulfilled by the Witnet blockchain
    /// @dev when solving a data request.
    WitnetV2.RadonSLA internal __witnetDefaultSLA;

    /// @dev Percentage over base fee to pay on every data request, 
    /// @dev as to deal with volatility of evmGasPrice and evmWitPrice during the live time of 
    /// @dev a data request (since being posted until a result gets reported back), at both the EVM and 
    /// @dev the Witnet blockchain levels, respectivelly. 
    uint16 internal __witnetBaseFeeOverheadPercentage;

    /// @param _wrb Address of the WitnetOracle contract.
    constructor(WitnetOracle _wrb) {
        require(
            _wrb.specs() == type(IWitnetOracle).interfaceId,
            "UsingWitnet: uncompliant WitnetOracle"
        );
        __witnet = _wrb;
        __witnetDefaultSLA = WitnetV2.RadonSLA({
            // Number of nodes in the Witnet blockchain that will take part in solving the data request:
            committeeSize: 10,
            // Fee in $nanoWIT paid to every node in the Witnet blockchain involved in solving the data request:
            witnessingFeeNanoWit: 20 * 10 ** 8  // defaults to 0.2 $WIT
        });
        
        __witnetBaseFeeOverheadPercentage = 10; // defaults to 10%
    }

    /// @dev Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// @dev contract until a particular request has been successfully solved and reported by Witnet,
    /// @dev either with an error or successfully.
    modifier witnetQuerySolved(uint256 _witnetQueryId) {
        require(_witnetCheckQueryResultAvailability(_witnetQueryId), "UsingWitnet: unsolved query");
        _;
    }

    function witnet() virtual public view returns (WitnetOracle) {
        return __witnet;
    }

    /// @notice Check if given query was already reported back from the Witnet oracle.
    /// @param _id The unique identifier of a previously posted data request.
    function _witnetCheckQueryResultAvailability(uint256 _id)
        internal view
        returns (bool)
    {
        return __witnet.getQueryStatus(_id) == WitnetV2.QueryStatus.Reported;
    }

    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function _witnetEstimateEvmReward(uint16 _resultMaxSize)
        virtual internal view
        returns (uint256)
    {
        return (
            (100 + __witnetBaseFeeOverheadPercentage)
                * __witnet.estimateBaseFee(tx.gasprice, _resultMaxSize) 
        ) / 100;
    }

    function _witnetCheckQueryResponseStatus(uint256 _witnetQueryId)
        internal view
        returns (WitnetV2.ResponseStatus)
    {
        return __witnet.getQueryResponseStatus(_witnetQueryId);
    }

    function _witnetCheckQueryResultError(uint256 _witnetQueryId)
        internal view
        returns (Witnet.ResultError memory)
    {
        return __witnet.getQueryResultError(_witnetQueryId);
    }
}
