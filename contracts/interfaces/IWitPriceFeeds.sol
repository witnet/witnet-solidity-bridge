// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPriceFeedsSolver.sol";

interface IWitPriceFeeds {   
    /// ======================================================================================================
    /// --- IFeeds extension ---------------------------------------------------------------------------------
    
    function lookupDecimals(bytes4 feedId) external view returns (uint8);    
    function lookupPriceSolver(bytes4 feedId) external view returns (
            IWitPriceFeedsSolver solverAddress, 
            string[] memory solverDeps
        );

    /// ======================================================================================================
    /// --- IWitFeeds extension ---------------------------------------------------------------------------

    function latestPrice(bytes4 feedId) external view returns (IWitPriceFeedsSolver.Price memory);
    function latestPrices(bytes4[] calldata feedIds)  external view returns (IWitPriceFeedsSolver.Price[] memory);
}