// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IChainlinkAggregatorV3.sol";
import "./IWitPyth.sol";

interface IPythChainlinkAggregatorV3 is IChainlinkAggregatorV3 {
    function priceId() external view returns (IWitPyth.ID);
    function pyth() external view returns (IWitPyth);
}
