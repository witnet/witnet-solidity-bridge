// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./libs/WitnetParserLib.sol";
import "./WitnetRequestBoard.sol";

/// @title The UsingWitnet contract
/// @dev Contract writers can inherit this contract in order to create Witnet data requests. 
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
    /// contract until a particular request has been successfully resolved by Witnet
    modifier witnetRequestResolved(uint256 _id) {
        require(
                _witnetCheckRequestResolved(_id),
                "UsingWitnet: request not yet solved"
            );
        _;
    }

    /// @notice Check if a request has been resolved by Witnet.
    /// @dev Contracts depending on Witnet should not start their main business logic (e.g. receiving value from third.
    /// parties) before this method returns `Witnet.QueryStatus.Reported`.
    /// @param _id The unique identifier of a previously posted request.
    /// @return A boolean telling if the request has been already resolved or not. Returns `false` if called after destroying the result (i.e. `destroyResult(uint256 _id).
    function _witnetCheckRequestResolved(uint256 _id) internal view returns (bool) {
        return _WRB.getQueryStatus(_id) == Witnet.QueryStatus.Reported;
    }

    /// @notice Retrieves result of a previously posted request, and removes the whole query from the WRB's storage.
    /// @param _id The unique identifier of a previously posted request.
    /// @return The Witnet-provided result to the request.
    function _witnetDestroyResult(uint256 _id) internal returns (Witnet.Result memory) {
        return _WRB.destroyResult(_id).resultFromCborBytes();
    }

    /// @notice Estimate the reward amount.
    /// @param _gasPrice The gas price for which we want to retrieve the estimation.
    /// @return The reward to be included for the given gas price.
    function _witnetEstimateGasCost(uint256 _gasPrice) internal view returns (uint256) {
        return _WRB.estimateReward(_gasPrice);
    }

    /// @notice Send a new request to the Witnet network with transaction value as result report reward.
    /// @param _script An instance of `IWitnetRadon` contract.
    /// @return Sequencial identifier for the request included in the WitnetRequestBoard.
    function _witnetPostRequest(IWitnetRadon _script) internal returns (uint256) {
        return _WRB.postRequest{value: msg.value}(_script);
    }

    /// @notice Read the result of a resolved request.
    /// @param _id The unique identifier of a request that was posted to Witnet.
    /// @return The result of the request as an instance of `Result`.
    function _witnetReadResult(uint256 _id) internal view returns (Witnet.Result memory) {
        return _WRB.readResponseWitnetResult(_id).resultFromCborBytes();
    } 

    /// @notice Upgrade the reward for a previously posted request.
    /// @dev Call to `upgradeRequest` function in the WitnetRequestBoard contract.
    /// @param _id The unique identifier of a request that has been previously sent to the WitnetRequestBoard.
    function _witnetUpgradeRequest(uint256 _id) internal {
        _WRB.upgradeRequest{value: msg.value}(_id);
    }

}
