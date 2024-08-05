// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitOracle.sol";

/// @title The UsingWitOracle contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitOracle
    is
        IWitOracleEvents
{
    /// @dev Immutable reference to the Witnet Request Board contract.
    WitOracle internal immutable __witOracle;
    
    /// @dev Default Security-Level Agreement parameters to be fulfilled by the Witnet blockchain
    /// @dev when solving a data request.
    Witnet.RadonSLA internal __witOracleDefaultSLA;

    /// @dev Percentage over base fee to pay on every data request, 
    /// @dev as to deal with volatility of evmGasPrice and evmWitPrice during the live time of 
    /// @dev a data request (since being posted until a result gets reported back), at both the EVM and 
    /// @dev the Witnet blockchain levels, respectivelly. 
    uint16 internal __witOracleBaseFeeOverheadPercentage;

    /// @param _wrb Address of the WitOracle contract.
    constructor(WitOracle _wrb) {
        require(
            _wrb.specs() == type(WitOracle).interfaceId,
            "UsingWitOracle: uncompliant WitOracle"
        );
        __witOracle = _wrb;
        __witOracleDefaultSLA = Witnet.RadonSLA({
            // Number of nodes in the Witnet blockchain that will take part in solving the data request:
            witNumWitnesses: 10,
            // Reward in $nanoWIT to be paid to every node in the Witnet blockchain involved in solving some data query.
            witUnitaryReward: 2 * 10 ** 8,  // defaults to 0.2 $WIT
            // Maximum size accepted for the CBOR-encoded buffer containing successfull result values.
            maxTallyResultSize: 32
        });
        
        __witOracleBaseFeeOverheadPercentage = 33; // defaults to 33%
    }

    /// @dev Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// @dev contract until a particular request has been successfully solved and reported by Witnet,
    /// @dev either with an error or successfully.
    modifier witnetQuerySolved(uint256 _queryId) {
        require(_witOracleCheckQueryResultAvailability(_queryId), "UsingWitOracle: unsolved query");
        _;
    }

    function witOracle() virtual public view returns (WitOracle) {
        return __witOracle;
    }

    /// @notice Check if given query was already reported back from the Witnet oracle.
    /// @param _id The unique identifier of a previously posted data request.
    function _witOracleCheckQueryResultAvailability(uint256 _id)
        internal view
        returns (bool)
    {
        return __witOracle.getQueryStatus(_id) == Witnet.QueryStatus.Reported;
    }

    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    function _witOracleEstimateBaseFee()
        virtual internal view
        returns (uint256)
    {
        return (
            (100 + __witOracleBaseFeeOverheadPercentage)
                * __witOracle.estimateBaseFee(tx.gasprice) 
        ) / 100;
    }

    function _witOracleCheckQueryQueryResponseStatus(uint256 _queryId)
        internal view
        returns (Witnet.QueryResponseStatus)
    {
        return __witOracle.getQueryResponseStatus(_queryId);
    }

    function _witOracleCheckQueryResultError(uint256 _queryId)
        internal view
        returns (Witnet.ResultError memory)
    {
        return __witOracle.getQueryResultError(_queryId);
    }
}
