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

  Witnet.Result public result;

  constructor (WitnetRequestBoard _wrb)
    UsingWitnet(_wrb)
  {}

  receive() external payable {}

  function witnetPostRequest(IWitnetRequest _request)
    external payable
    returns(uint256 _id)
  {
    uint256 _reward;
    (_id, _reward) = _witnetPostRequest(_request);
    if (_reward < msg.value) {
      payable(msg.sender).transfer(msg.value - _reward);
    }
  }

  function witnetUpgradeReward(uint256 _id)
    external payable
  {
    uint256 _value = msg.value;
    uint256 _used = _witnetUpgradeReward(_id);
    if (_used < _value) {
      payable(msg.sender).transfer(_value - _used);
    }
  }

  function witnetReadResult(uint256 _requestId)
    external
    returns (Witnet.Result memory)
  {
    result = _witnetReadResult(_requestId);
    return result;
  }

  function witnetCurrentReward(uint256 _requestId)
    external view
    returns (uint256)
  {
    return witnet.readRequestReward(_requestId);
  }

  function witnetEstimateReward(uint256 _gasPrice) external view returns (uint256) {
    return witnet.estimateReward(_gasPrice);
  }

  function witnetAsUint64() external view returns (uint64) {
    return witnet.asUint64(result);
  }

  function witnetCheckRequestResolved(uint256 _id) external view returns (bool) {
    return _witnetCheckResultAvailability(_id);
  }
}
