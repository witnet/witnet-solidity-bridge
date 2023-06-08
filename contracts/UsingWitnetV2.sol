// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBoardV2.sol";

/// @title The UsingWitnetV2 contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitnetV2 {

    /// @dev Immutable address to the WitnetRequestBoardV2 contract.
    WitnetRequestBoardV2 public immutable witnet;

    /// @dev Include an address to specify the WitnetRequestBoard entry point address.
    /// @param _wrb The WitnetRequestBoard entry point address.
    constructor(WitnetRequestBoardV2 _wrb)
    {
        require(
            _wrb.class() == type(WitnetRequestBoardV2).interfaceId,
            "UsingWitnetV2: uncompliant request board"
        );
        witnet = _wrb;
    }

    /// @dev Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// @dev contract until a particular data query has been successfully solved and reported by Witnet,
    /// @dev either with an error or successfully.
    modifier witnetQueryInStatus(bytes32 _queryHash, WitnetV2.QueryStatus _queryStatus) {
        require(
            witnet.checkQueryStatus(_queryHash) == _queryStatus, 
            "UsingWitnetV2: unexpected query status");
        _;
    }

    /// @notice Returns EVM gas price within the context of current transaction.
    function _getTxGasPrice() virtual internal view returns (uint256) {
        return tx.gasprice;
    }

    /// @notice Estimate the minimum reward in EVM/wei required for posting the described Witnet data request.
    /// @param _radHash The hash of the query's data request part (previously registered in `witnet.registry()`).
    /// @param _slaParams The query's SLA parameters.
    /// @param _witEvmPrice The price of 1 nanoWit in EVM/wei to be used when estimating query rewards.
    /// @param _maxEvmGasPrice The maximum EVM gas price willing to pay upon result reporting.
    function _witnetEstimateQueryReward(
            bytes32 _radHash,
            WitnetV2.RadonSLAv2 memory _slaParams,
            uint256 _witEvmPrice,
            uint256 _maxEvmGasPrice
        )
        internal view
        returns (uint256)
    {
        return witnet.estimateQueryReward(_radHash, _slaParams, _witEvmPrice, _maxEvmGasPrice, 0);
    }

    /// @notice Post some data request to be eventually solved by the Witnet decentralized oracle network.
    /// @dev Enough EVM coins need to be provided as to cover for the implicit cost and bridge rewarding.
    /// @param _radHash The hash of the query's data request part (previously registered in `witnet.registry()`).
    /// @param _slaParams The query's SLA parameters.
    /// @param _witEvmPrice The price of 1 nanoWit in EVM/wei to be used when estimating query rewards.
    /// @param _maxEvmGasPrice The maximum EVM gas price willing to pay upon result reporting.
    /// @return _queryHash The unique identifier of the new data query.
    /// @return _queryReward The actual amount escrowed into the WRB as query reward.
    function _witnetPostQuery(
            bytes32 _radHash, 
            WitnetV2.RadonSLAv2 memory _slaParams,
            uint256 _witEvmPrice,
            uint256 _maxEvmGasPrice
        )
        virtual internal
        returns (bytes32 _queryHash, uint256 _queryReward)
    {
        _queryReward = _witnetEstimateQueryReward(_radHash, _slaParams, _witEvmPrice, _maxEvmGasPrice);
        require(_queryReward <= msg.value, "UsingWitnetV2: EVM reward too low");
        _queryHash = witnet.postQuery{value: _queryReward}(_radHash, _slaParams);
    }

    /// @notice Post some data request to be eventually solved by the Witnet decentralized oracle network.
    /// @dev Enough EVM coins need to be provided as to cover for the implicit cost and bridge rewarding.
    /// @dev Implicitly sets `tx.gasprice` as the maximum EVM gas price expected to be paid upon result reporting.
    /// @param _radHash The hash of the query's data request part (previously registered in `witnet.registry()`).
    /// @param _slaParams The query's SLA parameters.
    /// @param _witEvmPrice The price of 1 nanoWit in EVM/wei to be used when estimating query rewards.
    /// @return _queryHash The unique identifier of the new data query.
    /// @return _queryReward The actual amount escrowed into the WRB as query reward.
    function _witnetPostQuery(bytes32 _radHash, WitnetV2.RadonSLAv2 memory _slaParams, uint256 _witEvmPrice)
        virtual internal
        returns (bytes32 _queryHash, uint256 _queryReward)
    {
        return _witnetPostQuery(_radHash, _slaParams, _witEvmPrice, _getTxGasPrice());
    }
}
