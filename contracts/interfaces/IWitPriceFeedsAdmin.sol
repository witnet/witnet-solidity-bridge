// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPriceFeeds.sol";
import "./IWitPriceFeedsMappingSolver.sol";
import "../libs/Witnet.sol";

interface IWitPriceFeedsAdmin {

    event PriceFeedMapping(
            address indexed from, IWitPriceFeeds.ID4, string symbol, int8 exponent, 
            IWitPriceFeedsMappingSolver solver, 
            string[] dependencies
        );

    event PriceFeedSettled(
            address indexed from, IWitPriceFeeds.ID4, string symbol, int8 exponent, 
            Witnet.RadonHash radonHash
        );
    
    event PriceFeedRemoved(address indexed from, IWitPriceFeeds.ID4, string symbol);

    struct WitParams {
        uint16 minWitCommitteeSize;
        uint16 maxWitCommitteeSize;
    }
    
    function createPriceFeedSolver(bytes calldata initcode, bytes calldata additionalParams) external returns (IWitPriceFeedsMappingSolver);
    function determinePriceFeedSolverAddress(bytes calldata initcode, bytes calldata additionalParams) external returns (address);
    function removePriceFeed(string calldata, bool) external returns (bytes4);
    function settleDefaultUpdateConditions(IWitPriceFeeds.UpdateConditions calldata) external;
    function settlePriceFeedMapping(string calldata, IWitPriceFeedsMappingSolver, string[] calldata, int8) external returns (bytes4);
    function settlePriceFeedRadonBytecode(string calldata, bytes calldata, int8) external returns (bytes4);
    function settlePriceFeedRadonHash(string calldata, Witnet.RadonHash, int8) external returns (bytes4);
    function settlePriceFeedUpdateConditions(string calldata, IWitPriceFeeds.UpdateConditions calldata) external;
    function settleWitOracleRequiredParams(WitParams calldata) external;
}
