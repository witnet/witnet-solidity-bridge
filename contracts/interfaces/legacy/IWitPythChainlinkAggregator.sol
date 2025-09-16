// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IPythChainlinkAggregatorV3.sol";

interface IWitPythChainlinkAggregator is IPythChainlinkAggregatorV3 {
    function id4() external view returns (bytes4);
    function symbol() external view returns (string memory);
    function witOracle() external view returns (address);
}
