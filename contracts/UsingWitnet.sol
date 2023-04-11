// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBoard.sol";

/// @title The UsingWitnet contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitnet {

    WitnetRequestBoard public immutable witnet;

    /// @dev Include an address to specify the WitnetRequestBoard entry point address.
    /// @param _wrb The WitnetRequestBoard entry point address.
    constructor(WitnetRequestBoard _wrb)
    {
        require(address(_wrb) != address(0), "UsingWitnet: no WRB");
        witnet = _wrb;
    }

    /// @dev Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// @dev contract until a particular request has been successfully solved and reported by Witnet,
    /// @dev either with an error or successfully.
    modifier witnetQuerySolved(uint256 _id) {
        require(_witnetCheckResultAvailability(_id), "UsingWitnet: unsolved query");
        _;
    }

    /// @notice Check if given query was already reported back from the Witnet oracle.
    /// @param _id The unique identifier of a previously posted data request.
    function _witnetCheckResultAvailability(uint256 _id)
        internal view
        returns (bool)
    {
        return witnet.getQueryStatus(_id) == Witnet.QueryStatus.Reported;
    }

    /// @notice Estimate the reward amount.
    /// @param _gasPrice The gas price for which we want to retrieve the estimation.
    /// @return The reward to be included when either posting a new request, or upgrading the reward of a previously posted one.
    function _witnetEstimateReward(uint256 _gasPrice)
        internal view
        returns (uint256)
    {
        return witnet.estimateReward(_gasPrice);
    }

    /// @notice Estimates the reward amount, considering current transaction gas price.
    /// @return The reward to be included when either posting a new request, or upgrading the reward of a previously posted one.
    function _witnetEstimateReward()
        internal view
        returns (uint256)
    {
        return witnet.estimateReward(tx.gasprice);
    }

    /// @notice Post some data request to be eventually solved by the Witnet decentralized oracle network.
    /// @dev Enough ETH needs to be provided as to cover for the implicit fee.
    /// @param _request An instance of some contract implementing the `IWitnetRequest` interface.
    /// @return _id Sequential identifier for the request included in the WitnetRequestBoard.
    /// @return _reward Current reward amount escrowed by the WRB until a result gets reported.
    function _witnetPostRequest(IWitnetRequest _request)
        virtual internal
        returns (uint256 _id, uint256 _reward)
    {
        _reward = _witnetEstimateReward();
        require(
            _reward <= msg.value,
            "UsingWitnet: reward too low"
        );
        _id = witnet.postRequest{value: _reward}(_request);
    }

    /// @notice Post some data request to be eventually solved by the Witnet decentralized oracle network.
    /// @dev Enough ETH needs to be provided as to cover for the implicit fee.
    /// @param _radHash Unique hash of some pre-validated Witnet Radon Request.
    /// @param _slaHash Unique hash of some pre-validated Witnet Radon Service-Level Agreement.
    /// @param _id The unique identifier of the just posted data request.
    /// @return _reward Current reward amount escrowed by the WRB until a result gets reported.
    function _witnetPostRequest(bytes32 _radHash, bytes32 _slaHash)
        virtual internal
        returns (uint256 _id, uint256 _reward)
    {
        _reward = _witnetEstimateReward();
        require(
            _reward <= msg.value,
            "UsingWitnet: reward too low"
        );
        _id = witnet.postRequest{value: _reward}(_radHash, _slaHash);
    }

    /// @notice Read the Witnet-provided result to a previously posted request.
    /// @dev Reverts if the data request was not yet solved.
    /// @param _id The unique identifier of some previously posted data request.
    /// @return The result of the request as an instance of `Witnet.Result`.
    function _witnetReadResult(uint256 _id)
        internal view
        virtual
        returns (Witnet.Result memory)
    {
        return witnet.readResponseResult(_id);
    }

    /// @notice Upgrade the reward of some previously posted data request.
    /// @dev Reverts if the data request was already solved.
    /// @param _id The unique identifier of some previously posted data request.
    /// @return Amount in which the reward has been increased.
    function _witnetUpgradeReward(uint256 _id)
        virtual internal
        returns (uint256)
    {
        uint256 _currentReward = witnet.readRequestReward(_id);        
        uint256 _newReward = _witnetEstimateReward();
        uint256 _fundsToAdd = 0;
        if (_newReward > _currentReward) {
            _fundsToAdd = (_newReward - _currentReward);
        }
        witnet.upgradeReward{value: _fundsToAdd}(_id); 
        return _fundsToAdd;
    }
}