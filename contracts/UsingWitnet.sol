// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libs/WitnetParserLib.sol";
import "./WitnetRequestBoard.sol";

/// @title The UsingWitnet contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitnet {

    using WitnetParserLib for bytes;
    WitnetRequestBoard internal immutable _WRB;

    /// @notice Include an address to specify the WitnetRequestBoard entry point address.
    /// @param _wrb The WitnetRequestBoard entry point address.
    constructor(WitnetRequestBoard _wrb) {
        require(address(_wrb) != address(0), "UsingWitnet: zero address");
        _WRB = _wrb;
    }

    /// Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// contract until a particular request has been successfully solved and reported by Witnet.
    modifier WitnetRequestSolved(uint256 _id) {
        require(
                _witnetCheckResultAvailability(_id),
                "UsingWitnet: request not solved"
            );
        _;
    }

    /// Check if a data request has been solved and reported by Witnet.
    /// @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third.
    /// parties) before this method returns `true`.
    /// @param _id The unique identifier of a previously posted data request.
    /// @return A boolean telling if the request has been already resolved or not. Returns `false` also, if the result was deleted.
    function _witnetCheckResultAvailability(uint256 _id) internal view returns (bool) {
        return _WRB.getQueryStatus(_id) == Witnet.QueryStatus.Reported;
    }

    /// Retrieves copy of all response data related to a previously posted request, removing the whole query from storage.
    /// @param _id The unique identifier of a previously posted request.
    /// @return The Witnet-provided result to the request.
    function _witnetDeleteQuery(uint256 _id) internal returns (Witnet.Response memory) {
        return _WRB.deleteQuery(_id);
    }

    /// Estimate the reward amount.
    /// @param _gasPrice The gas price for which we want to retrieve the estimation.
    /// @return The reward to be included for the given gas price.
    function _witnetEstimateReward(uint256 _gasPrice) internal view returns (uint256) {
        return _WRB.estimateReward(_gasPrice);
    }

    /// Send a new request to the Witnet network with transaction value as a reward.
    /// @param _request An instance of `IWitnetRequest` contract.
    /// @return Sequential identifier for the request included in the WitnetRequestBoard.
    function _witnetPostRequest(IWitnetRequest _request) internal returns (uint256) {
        return _WRB.postRequest{value: msg.value}(_request);
    }

    /// Read the Witnet-provided result to a previously posted request.
    /// @param _id The unique identifier of a request that was posted to Witnet.
    /// @return The result of the request as an instance of `Witnet.Result`.
    function _witnetReadResult(uint256 _id) internal view returns (Witnet.Result memory) {
        return _WRB.readResponseResult(_id).resultFromCborBytes();
    }

    /// Upgrade the reward for a previously posted request.
    /// @dev Call to `upgradeReward` function in the WitnetRequestBoard contract.
    /// @param _id The unique identifier of a request that has been previously sent to the WitnetRequestBoard.
    function _witnetUpgradeReward(uint256 _id) internal {
        _WRB.upgradeReward{value: msg.value}(_id);
    }

}
