// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../contracts/Request.sol";
import "../../contracts/Witnet.sol";
import "../../contracts/UsingWitnet.sol";


/**
 * @title Test Helper for the UsingWitnet contract
 * @dev The aim of this contract is:
 * 1. Raise the visibility modifier of UsingWitnet contract functions for testing purposes
 * @author Witnet Foundation
 */
contract UsingWitnetTestHelper is UsingWitnet {
  using Witnet for Witnet.Result;

  Witnet.Result public result;

  constructor (address _wrbAddress) public UsingWitnet(_wrbAddress) { }

  function _witnetPostRequest(Request _request, uint256 _requestReward, uint256 _tallyReward) external payable returns(uint256 id) {
    return witnetPostRequest(_request, _requestReward, _tallyReward);
  }

  function _witnetUpgradeRequest(uint256 _id, uint256 _requestReward, uint256 _tallyReward) external payable {
    witnetUpgradeRequest(_id, _requestReward, _tallyReward);
  }

  function _witnetReadResult(uint256 _requestId) external returns(Witnet.Result memory) {
    result = witnetReadResult(_requestId);
    return result;
  }

  function _witnetAsUint64() external view returns(uint64) {
    return result.asUint64();
  }

}
