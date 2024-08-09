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
    /// @notice Immutable reference to the WitOracle contract.
    function witOracle() virtual public view returns (WitOracle) {
        return __witOracle;
    }
    WitOracle internal immutable __witOracle;
    
    /// @dev Percentage over base fee to pay on every data request, 
    /// @dev as to deal with volatility of evmGasPrice and evmWitPrice during the live time of 
    /// @dev a data request (since being posted until a result gets reported back), at both the EVM and 
    /// @dev the Witnet blockchain levels, respectivelly. 
    uint16 internal __witOracleBaseFeeOverheadPercentage;

    /// @notice Default SLA data security parameters to be fulfilled by the Wit/oracle blockchain
    /// @notice when solving a data request.
    function witOracleDefaultQuerySLA() virtual public view returns (Witnet.RadonSLA memory) {
        return __witOracleDefaultQuerySLA;
    }
    Witnet.RadonSLA internal __witOracleDefaultQuerySLA;

    /// @dev Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// @dev contract until a particular request has been successfully solved and reported from the Wit/oracle blockchain,
    /// @dev either with an error or successfully.
    modifier witOracleQuerySolved(uint256 _queryId) {
        require(_witOracleCheckQueryResultAvailability(_queryId), "UsingWitOracle: unsolved query");
        _;
    }

    /// @param _witOracle Address of the WitOracle bridging contract.
    constructor(WitOracle _witOracle) {
        require(
            _witOracle.specs() == type(WitOracle).interfaceId,
            "UsingWitOracle: uncompliant WitOracle"
        );
        __witOracle = _witOracle;
        __witOracleDefaultQuerySLA = Witnet.RadonSLA({
            witNumWitnesses: 10,            // defaults to 10 witnesses
            witUnitaryReward: 2 * 10 ** 8,  // defaults to 0.2 witcoins
            maxTallyResultSize: 32          // defaults to 32 bytes
        });
        
        __witOracleBaseFeeOverheadPercentage = 33; // defaults to 33%
    }

    /// @dev Check if given query was already reported back from the Wit/oracle blockchain.
    /// @param _id The unique identifier of a previously posted data request.
    function _witOracleCheckQueryResultAvailability(uint256 _id)
        internal view
        returns (bool)
    {
        return __witOracle.getQueryStatus(_id) == Witnet.QueryStatus.Reported;
    }

    /// @dev Returns a struct describing the resulting error from some given query id.
    function _witOracleCheckQueryResultError(uint256 _queryId)
        internal view
        returns (Witnet.ResultError memory)
    {
        return __witOracle.getQueryResultError(_queryId);
    }

    /// @dev Return current response status to some given gquery id.
    function _witOracleCheckQueryResponseStatus(uint256 _queryId)
        internal view
        returns (Witnet.QueryResponseStatus)
    {
        return __witOracle.getQueryResponseStatus(_queryId);
    }

    /// @dev Estimate the minimum reward required for posting a data request (based on `tx.gasprice`).
    function _witOracleEstimateBaseFee()
        virtual internal view
        returns (uint256)
    {
        return (
            (100 + __witOracleBaseFeeOverheadPercentage)
                * __witOracle.estimateBaseFee(tx.gasprice) 
        ) / 100;
    }
}
