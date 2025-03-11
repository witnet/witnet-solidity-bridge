// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IPythChainlinkAggregatorV3.sol";

interface IWitPythChainlinkAggregator is IPythChainlinkAggregatorV3 {
    function wit() external view returns (address);
}
