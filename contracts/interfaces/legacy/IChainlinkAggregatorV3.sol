// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IChainlinkAggregatorV3 {

    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    
    function getRoundData(uint80 _roundId)
        external view returns (
            uint80 roundId, 
            int256 answer, 
            uint256 startedAt, 
            uint256 updatedAt, 
            uint80 answeredInRound
        );

    function latestRoundData()
        external view returns (
            uint80 roundId, 
            int256 answer, 
            uint256 startedAt, 
            uint256 updatedAt, 
            uint80 answeredInRound
        );

    function version() external view returns (uint256);
}
