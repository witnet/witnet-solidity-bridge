// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitPriceFeeds.sol";
import "./IWitPriceFeedsMappingSolver.sol";
import "../libs/Witnet.sol";

interface IWitPriceFeedsAdmin {

    event PriceFeedMapper(
            address indexed from, IWitPriceFeeds.ID4 id4, string symbol, int8 exponent, 
            IWitPriceFeeds.Mappers mapper,
            string[] dependencies
        );

    event PriceFeedOracle(
            address indexed from, IWitPriceFeeds.ID4 id4, string symbol, int8 exponent, 
            IWitPriceFeeds.Oracles oracle,
            address oracleAddress,
            bytes32 oracleSources
        );
    
    event PriceFeedRemoved(address indexed from, IWitPriceFeeds.ID4 id4, string symbol);

    event PriceFeedSettled(
        address indexed from, IWitPriceFeeds.ID4 id4, string symbol,
        IWitPriceFeeds.UpdateConditions conditions
    );
    
    function acceptOwnership() external;
    function defaultUpdateConditions() external view returns (IWitPriceFeeds.UpdateConditions calldata);
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function removePriceFeed(string calldata, bool) external returns (bytes4);
    function settleConsumer(address) external;
    function settleDefaultUpdateConditions(IWitPriceFeeds.UpdateConditions calldata) external;
    function settlePriceFeedMapper(string calldata, int8, IWitPriceFeeds.Mappers, string[] calldata) external returns (bytes4);
    function settlePriceFeedOracle(string calldata, int8, IWitPriceFeeds.Oracles, address, bytes32) external returns (bytes4);
    function settlePriceFeedRadonBytecode(string calldata, int8, bytes calldata) external returns (bytes4);
    function settlePriceFeedRadonHash(string calldata, int8, Witnet.RadonHash) external returns (bytes4);
    function settlePriceFeedUpdateConditions(string calldata, IWitPriceFeeds.UpdateConditions calldata) external;
    function transferOwnership(address) external;
}
