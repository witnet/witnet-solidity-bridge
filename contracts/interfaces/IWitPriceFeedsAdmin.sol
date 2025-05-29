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

    struct WitParams {
        uint16 maxWitCommitteeSize;
        uint16 minWitCommitteeSize;
    }
    
    function removePriceFeed(string calldata, bool) external returns (bytes4);
    function settleDefaultUpdateConditions(IWitPriceFeeds.UpdateConditions calldata) external;
    function settlePriceFeedMapper(string calldata, int8, IWitPriceFeeds.Mappers, string[] calldata) external returns (bytes4);
    function settlePriceFeedOracle(string calldata, int8, IWitPriceFeeds.Oracles, address, bytes32) external returns (bytes4);
    function settlePriceFeedRadonBytecode(string calldata, int8, bytes calldata) external returns (bytes4);
    function settlePriceFeedRadonHash(string calldata, int8, Witnet.RadonHash) external returns (bytes4);
    function settlePriceFeedUpdateConditions(string calldata, IWitPriceFeeds.UpdateConditions calldata) external;
    function settleWitOracleRequiredParams(WitParams calldata) external;
    function witOracleRequiredParams() external view returns (WitParams memory);
}
