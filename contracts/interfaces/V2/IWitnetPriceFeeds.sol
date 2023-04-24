// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitnetPriceSolver.sol";

interface IWitnetPriceFeeds {   
    /// ======================================================================================================
    /// --- IFeeds extension ---------------------------------------------------------------------------------
    
    function lookupDecimals(bytes4 feedId) external view returns (uint8);    
    function lookupPriceSolver(bytes4 feedId) external view returns (IWitnetPriceSolver);

    /// ======================================================================================================
    /// --- IWitnetFeeds extension ---------------------------------------------------------------------------

    function latestPrice(bytes4 feedId) external view returns (IWitnetPriceSolver.Price memory);
    function latestPrices(bytes4[] calldata feedIds)  external view returns (IWitnetPriceSolver.Price[] memory);
}