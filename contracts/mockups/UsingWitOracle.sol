// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitOracle.sol";

/// @title The UsingWitOracle contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitOracle
    is
        IWitOracleQueriableEvents
{   
    /// @notice Immutable reference to the WitOracle contract.
    function witOracle() virtual public view returns (address) {
        return address(__witOracle);
    }
    WitOracle internal immutable __witOracle;
    
    /// @dev Percentage over base fee to pay on every data request, 
    /// @dev as to deal with volatility of evmGasPrice and evmWitPrice during the live time of 
    /// @dev a data request (since being posted until a result gets reported back), at both the EVM and 
    /// @dev the Witnet blockchain levels, respectivelly. 
    uint16 internal __witOracleBaseFeeOverheadPercentage;

    /// @notice Default SLA data security parameters to be fulfilled by the Wit/Oracle blockchain
    /// @notice when solving a data request.
    Witnet.QuerySLA internal __witOracleDefaultQueryParams;

    /// @dev Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// @dev contract until a particular request has been successfully solved and reported from the Wit/Oracle blockchain,
    /// @dev either with an error or successfully.
    modifier witOracleQuerySolved(Witnet.QueryId _queryId) {
        Witnet.QueryStatus _queryStatus = _witOracleCheckQueryStatus(_queryId);
        require(
            _queryStatus == Witnet.QueryStatus.Finalized
                || _queryStatus == Witnet.QueryStatus.Expired
                || _queryStatus == Witnet.QueryStatus.Disputed
            , "UsingWitOracle: unsolved query"
        ); _;
    }

    /// @param _witOracle Address of the WitOracle bridging contract.
    constructor(address _witOracle) {
        require(
            IWitAppliance(_witOracle).specs() == (
                type(IWitOracle).interfaceId
                    ^ type(IWitOracleQueriable).interfaceId
            ), "UsingWitOracle: uncompliant WitOracle"
        );
        __witOracle = WitOracle(_witOracle);
        __witOracleDefaultQueryParams = Witnet.QuerySLA({
            witResultMaxSize: 32, // defaults to 32 bytes
            witCommitteeSize: 3,  // defaults to 10 witnesses
            witInclusionFees: 2 * 10 ** 8 // defaults to 0.2 $WIT
        });
        
        __witOracleBaseFeeOverheadPercentage = 33; // defaults to 33%
    }

    /// @dev Check if given query was already reported back from the Wit/Oracle blockchain.
    /// @param _id The unique identifier of a previously posted data request.
    function _witOracleCheckQueryStatus(Witnet.QueryId _id)
        internal view
        returns (Witnet.QueryStatus)
    {
        return __witOracle.getQueryStatus(_id);
    }

    /// @dev Estimate the minimum reward required for posting a data request (based on `tx.gasprice`).
    function _witOracleEstimateBaseFee() virtual internal view returns (uint256) {
        return _witOracleEstimateBaseFee(tx.gasprice);
    }

    function _witOracleEstimateBaseFee(uint256 _evmGasPrice) virtual internal view returns (uint256) {
        return (
            __witOracle.estimateBaseFee(_evmGasPrice)
                * (100 + __witOracleBaseFeeOverheadPercentage)
        ) / 100;
    }
}
