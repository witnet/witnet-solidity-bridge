// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../contracts/UsingWitnet.sol";

/**
 * @title Test Helper for the UsingWitnet contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of UsingWitnet contract functions for testing purposes
 * @author Witnet Foundation
 */
contract UsingWitnetTestHelper is UsingWitnet {
  using WitnetParserLib for Witnet.Result;

  Witnet.Result public result;

  constructor (WitnetRequestBoard _wrb)
    UsingWitnet(_wrb)
  {}

  function witnetPostRequest(IWitnetRequest _script)
    external payable
    returns(uint256 id)
  {
    return _witnetPostRequest(_script);
  }

  function witnetUpgradeRequest(uint256 _id)
    external payable
  {
    _witnetUpgradeReward(_id);
  }

  function witnetReadResult(uint256 _requestId)
    external
    returns (Witnet.Result memory)
  {
    result = _witnetReadResult(_requestId);
    return result;
  }

  function witnetEstimateGasCost(uint256 _gasPrice) external view returns (uint256) {
    return _witnetEstimateReward(_gasPrice);
  }

  function witnetAsUint64() external view returns (uint64) {
    return result.asUint64();
  }

  function witnetCheckRequestResolved(uint256 _id) external view returns (bool) {
    return _witnetCheckResultAvailability(_id);
  }
}
