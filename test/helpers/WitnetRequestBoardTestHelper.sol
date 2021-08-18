// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../contracts/impls/trustable/WitnetRequestBoardTrustableEVM.sol";

/**
 * @title Witnet Requests Board Version 1
 * @notice Contract to bridge requests to Witnet
 * @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network
  * The result of the requests will be posted back to this contract by the bridge nodes too.
  * The contract has been created for testing purposes
 * @author Witnet Foundation
 */
contract WitnetRequestBoardTestHelper
  is
    WitnetRequestBoardTrustableEVM
{
  address public witnet;

  constructor (address[] memory _committee, bool _upgradable)
    WitnetRequestBoardTrustableEVM(_upgradable, "WitnetRequestBoardTestHelper")
  {
    witnet = msg.sender;
    setReporters(_committee);
  }

  /// @dev Estimate the amount of reward we need to insert for a given gas price.
  /// @return The rewards to be included for the given gas price as inclusionReward, resultReward, blockReward.
  function estimateReward(uint256)
    external pure
    override
    returns(uint256)
  {
    return 0;
  }

  /// @dev Posts a data request into the WRB, with immediate mock result.
  /// @param _script The contract containing the Witnet Radon bytecode.
  /// @return _id The unique identifier of the data request.
  function postRequest(IWitnetRadon _script)
    public payable
    override
    returns(uint256 _id)
  {
    _id = super.postRequest(_script);
    _state().queries[_id].response.witnetProof = keccak256("hello");
    _state().queries[_id].response.witnetResult = "hello";
  }
}
