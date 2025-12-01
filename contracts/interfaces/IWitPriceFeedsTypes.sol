// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17 <0.9.0;

import {Witnet} from "../libs/Witnet.sol";
import {IWitPyth} from "./legacy/IWitPyth.sol";

interface IWitPriceFeedsTypes {

    enum Mappers {
        None,
        Fallback,
        Hottest,
        Product,
        Inverse
    }

    enum Oracles {
        Witnet,
        ERC2362,
        Chainlink,
        Pyth
    }

    struct Price {
        int8 exponent;
        uint64 price;
        int56  deltaPrice;
        Witnet.Timestamp timestamp;
        Witnet.TransactionHash trail;
    }

    struct PriceFeedInfo {
        IWitPyth.ID id;
        int8 exponent;
        string symbol;
        PriceFeedMapper mapper;
        PriceFeedOracle oracle;
        PriceUpdateConditions updateConditions;
        Price lastUpdate;
    }

    struct PriceFeedMapper {
        Mappers class;
        string[] deps;
    }

    struct PriceFeedOracle {
        Oracles class;
        address target;
        bytes32 sources;
    }

    struct PriceFeedQoS {
        bool   computesEMA;
        uint16 maxDeviation1000;
        uint24 maxSecsBetweenUpdates;
        uint24 minSecsBetweenUpdates;
        uint16 numFallbackOracles;
        uint16 numMappedPriceFeeds;
        uint16 numTrackableDataSources;
        uint16 witnessingCommitteeSize;
    }

    struct PriceUpdateConditions {
        uint24 callbackGas;
        bool   computeEMA;
        uint24 cooldownSecs;
        uint24 heartbeatSecs;
        uint16 maxDeviation1000;
        uint16 minWitnesses;
    }

    type ID4 is bytes4;
}