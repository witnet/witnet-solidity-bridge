// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17 <0.9.0;

import {IWitPriceFeedsTypes, Witnet} from "./IWitPriceFeedsTypes.sol";

interface IWitPriceFeedsEvents {
    /// Emitted when the curator settles a new routed price feed.
    event PriceFeedMapperSettled(
            address indexed from, 
            IWitPriceFeedsTypes.ID4 id4, 
            string caption, 
            int8 exponent, 
            IWitPriceFeedsTypes.Mappers mapper,
            string[] dependencies
        );

    /// Emitted when the curator settles a new oraclized price feed.
    event PriceFeedOracleSettled(
            address indexed from, 
            IWitPriceFeedsTypes.ID4 id4, 
            string caption, 
            int8 exponent, 
            IWitPriceFeedsTypes.Oracles oracle,
            address oracleAddress,
            bytes32 oracleSources
        );

    /// Emitted when the curator removes a price feeds from the list of supported price feeds.
    event PriceFeedRemoved(
        address indexed from, 
        IWitPriceFeedsTypes.ID4 id4, 
        string caption
    );

    /// Emitted when someone permissionlessly report a valid Witnet-certified update on the specified price feed,
    event PriceFeedUpdate(
        IWitPriceFeedsTypes.ID4 indexed id4,
        Witnet.Timestamp timestamp, 
        Witnet.TransactionHash trail,
        uint64 price,
        int56 deltaPrice,
        int8 exponent
    );

    /// Emitted when the curator updates conditions of some existing price feed get altered.
    event PriceFeedUpdateConditionsSettled(
        address indexed from, 
        IWitPriceFeedsTypes.ID4 id4, 
        string caption,
        IWitPriceFeedsTypes.PriceUpdateConditions conditions
    );
}