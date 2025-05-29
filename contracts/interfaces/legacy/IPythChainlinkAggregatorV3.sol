// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IChainlinkAggregatorV3.sol";
import "./IWitPyth.sol";

interface IPythChainlinkAggregatorV3 is IChainlinkAggregatorV3 {
    function priceId() external view returns (bytes32);
    function pyth() external view returns (address);
}
