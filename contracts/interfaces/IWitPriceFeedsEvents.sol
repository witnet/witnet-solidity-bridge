// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17 <0.9.0;

import {IWitPriceFeedsTypes, Witnet} from "./IWitPriceFeedsTypes.sol";

interface IWitPriceFeedsEvents {
    /// Emitted when a new routed price feed gets settled.
    event PriceFeedMapper(
            address indexed from, 
            IWitPriceFeedsTypes.ID4 id4, 
            string caption, 
            int8 exponent, 
            IWitPriceFeedsTypes.Mappers mapper,
            string[] dependencies
        );

    /// Emitted when a new oraclized price feed gets settled.
    event PriceFeedOracle(
            address indexed from, 
            IWitPriceFeedsTypes.ID4 id4, 
            string caption, 
            int8 exponent, 
            IWitPriceFeedsTypes.Oracles oracle,
            address oracleAddress,
            bytes32 oracleSources
        );

    /// Emitted when a price feeds gets removed from the list of supported price feeds.
    event PriceFeedRemoved(
        address indexed from, 
        IWitPriceFeedsTypes.ID4 id4, 
        string caption
    );

    event PriceFeedUpdate(
        IWitPriceFeedsTypes.ID4 indexed ID4,
        Witnet.Timestamp timestamp, 
        Witnet.TransactionHash trail,
        uint64 price,
        int56 deltaPrice,
        int8 exponent
    );

    /// Emitted when the update conditions of some existing price feed get altered.
    event PriceFeedUpdateConditions(
        address indexed from, 
        IWitPriceFeedsTypes.ID4 id4, 
        string caption,
        IWitPriceFeedsTypes.UpdateConditions conditions
    );
}