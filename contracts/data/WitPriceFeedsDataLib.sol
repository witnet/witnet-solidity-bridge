// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IChainlinkAggregatorV3} from "../interfaces/legacy/IChainlinkAggregatorV3.sol";
import {IERC2362} from "ado-contracts/contracts/interfaces/IERC2362.sol";
import {IWitPriceFeeds, IWitPriceFeedsTypes, IWitPyth} from "../interfaces/IWitPriceFeeds.sol";
import {IWitPythErrors} from "../interfaces/legacy/IWitPythErrors.sol";

import {
    IWitOracle,
    IWitOracleRadonRegistry,
    Witnet
} from "../WitOracle.sol";

import {WitPythChainlinkAggregator} from "../mockups/WitPythChainlinkAggregator.sol";

import "../libs/Slices.sol";

/// @title WitPriceFeeds data model.
/// @author The Witnet Foundation.
library WitPriceFeedsDataLib {

    using Slices for string;
    using Slices for Slices.Slice;

    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.QueryId;
    using Witnet for Witnet.RadonHash;
    using Witnet for Witnet.ResultStatus;
    using Witnet for Witnet.Timestamp;

    using WitPriceFeedsDataLib for IWitPriceFeedsTypes.ID4;
    using WitPriceFeedsDataLib for PriceFeed;
    
    bytes32 private constant _WIT_FEEDS_DATA_SLOTHASH =
        /* keccak256("io.witnet.feeds.data.v3") & ~bytes32(uint256(0xff) */
        0xc5354469a5d32189a18f5e79f9508d828fa089087c317bc89792b1c8dba53900;

    struct Storage {
        IWitPyth.ID[] ids;
        mapping (IWitPriceFeedsTypes.ID4 => PriceFeed) records;
        mapping (IWitPriceFeedsTypes.ID4 => IWitPriceFeedsTypes.ID4[]) reverseDeps;
        mapping (Witnet.RadonHash => IWitPriceFeedsTypes.ID4) reverseIds;
        IWitPriceFeedsTypes.PriceUpdateConditions _reserved;
        address consumer;
        bytes4  footprint;
    }

    struct PriceData {
        /// @dev Exponentially Moving Average proportional to actual time since previous update.
        uint64 emaPrice;
        
        /// @dev Price attested on the Witnet blockchain.
        uint64 price;
        
        /// @dev How much the price varied since previous update.
        int56 deltaPrice;
        
        /// @dev Base-10 exponent to compute actual price.
        int8 exponent;

        /// @dev Timestamp at which the price was attested on the Witnet blockchain.
        Witnet.Timestamp timestamp;

        /// @dev Auditory trail: price witnessing act on the Witnet blockchain.
        Witnet.TransactionHash trail;
    }

    struct PriceFeed {
        /// @dev Human-readable symbol for this price feed.
        string symbol;
        
        /// @dev (Required for removing price-feed settlements from storage)
        uint32 index;

        /// @dev Base-10 exponent to compute actual price.
        int8 exponent;

        /// @dev (40-bit reserve)
        int40 _reserved;
        
        /// @dev Price feed's mapping algorithm, if any.        
        IWitPriceFeedsTypes.Mappers mapper;

        /// @dev Price feed's aggregator oracle type, if other than the Wit/Oracle.
        IWitPriceFeedsTypes.Oracles oracle;

        /// @dev Price feed's aggregator oracle address, if other than the Wit/Oracle.
        address oracleAddress;

        /// @dev Unique ID identifying actual data sources and off-chain computations performed by 
        /// the selected oracle when retrieving a fresh update for this price feed 
        /// (e.g. Radon Request hash if oracle is the Wit/Oracle).
        bytes32 oracleSources;

        /// @dev 256-bit flag containing references up to 8x existing price feeds.
        bytes32 mapperDeps;

        /// @dev Price-feed specific update conditions, if other than defaults.
        IWitPriceFeedsTypes.PriceUpdateConditions updateConditions;

        /// @dev Last valid update data retrieved from the Wit/Oracle, if any.
        PriceData lastUpdate;
    }


    // ================================================================================================================
    // --- Public methods ---------------------------------------------------------------------------------------------

    function createChainlinkAggregator(IWitPriceFeedsTypes.ID4 id4) public returns (address) {
        bytes memory _initcode = type(WitPythChainlinkAggregator).creationCode;
        bytes memory _params = abi.encodePacked(address(this), id4);
        address _aggregator = _determineCreate2Address(_initcode, _params);
        if (_aggregator.code.length == 0) {
            bytes memory _bytecode = _completeInitCode(_initcode, _params);
            assembly {
                _aggregator := create2(
                    0,
                    add(_bytecode, 0x20),
                    mload(_bytecode),
                    0
                )
            }
        }
        return _aggregator;
    }

    function fetchLastUpdate(PriceFeed storage self, IWitPriceFeedsTypes.ID4 id4, uint24 heartbeat)
        public view 
        returns (PriceData memory _lastUpdate)
    {
        IWitPriceFeedsTypes.Mappers _mapper = self.mapper;
        if (_mapper == IWitPriceFeedsTypes.Mappers.None) {
            
            IWitPriceFeedsTypes.Oracles _oracle = self.oracle;
            if (_oracle == IWitPriceFeedsTypes.Oracles.Witnet) {
                if (self.oracleAddress == address(0) || self.oracleAddress == address(this)) {
                    return self.lastUpdate;
                
                } else {
                    return (
                        self.updateConditions.computeEMA
                            ? _intoEmaPriceData(IWitPriceFeeds(self.oracleAddress).getPriceNotOlderThan(
                                IWitPriceFeedsTypes.ID4.wrap(bytes4(self.oracleSources)), 
                                heartbeat
                            ))
                            : _intoPriceData(IWitPriceFeeds(self.oracleAddress).getPriceNotOlderThan(
                                IWitPriceFeedsTypes.ID4.wrap(bytes4(self.oracleSources)), 
                                heartbeat
                            ))
                    );
                }

            } else if (_oracle == IWitPriceFeedsTypes.Oracles.ERC2362) {
                (int _value, uint _timestamp,) = IERC2362(self.oracleAddress).valueFor(self.oracleSources);
                _lastUpdate.price = uint64(int64(_value));
                _lastUpdate.timestamp = Witnet.Timestamp.wrap(uint64(_timestamp));
                _lastUpdate.exponent = self.exponent;

            } else if (_oracle == IWitPriceFeedsTypes.Oracles.Chainlink) {
                (, int _value,, uint _timestamp,) = IChainlinkAggregatorV3(self.oracleAddress).latestRoundData();
                _lastUpdate.price = uint64(int64(_value));
                _lastUpdate.timestamp = Witnet.Timestamp.wrap(uint64(_timestamp));
                _lastUpdate.exponent = self.exponent;
            
            } else if (_oracle == IWitPriceFeedsTypes.Oracles.Pyth) {
                IWitPyth.PythPrice memory _price;
                if (self.updateConditions.computeEMA) {
                    _price = IWitPyth(self.oracleAddress).getEmaPriceUnsafe(IWitPyth.ID.wrap(self.oracleSources));
                    _lastUpdate.emaPrice = uint64(_price.price);
                } else {
                    _price = IWitPyth(self.oracleAddress).getPriceUnsafe(IWitPyth.ID.wrap(self.oracleSources));
                    _lastUpdate.price = uint64(_price.price);
                }
                _lastUpdate.timestamp = Witnet.Timestamp.wrap(uint64(_price.publishTime));
                _lastUpdate.exponent = int8(_price.expo);

            } else {
                revert("unsupported oracle");
            }
        
        } else {    
            if (
                _mapper == IWitPriceFeedsTypes.Mappers.Product 
                    || _mapper == IWitPriceFeedsTypes.Mappers.Inverse
            ) {
                return _fetchLastUpdateFromProduct(
                    id4, 
                    heartbeat, 
                    self.exponent, 
                    _mapper == IWitPriceFeedsTypes.Mappers.Inverse
                );

            } else if (_mapper == IWitPriceFeedsTypes.Mappers.Hottest) {
                return _fetchLastUpdateFromHottest(
                    id4, 
                    heartbeat,
                    self.exponent
                );
            
            } else if (_mapper == IWitPriceFeedsTypes.Mappers.Fallback) {
                return _fetchLastUpdateFromFallback(
                    id4, 
                    heartbeat,
                    self.exponent
                );

            } else {
                revert("unsupported mapper");
            }
        }
    }

    function getPrice(IWitPriceFeedsTypes.ID4 id4)
        public view 
        returns (IWitPriceFeedsTypes.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id4);
        IWitPriceFeedsTypes.PriceUpdateConditions memory _conditions = __record.updateConditions;

        PriceData memory _lastUpdate = fetchLastUpdate(__record, id4, _conditions.heartbeatSecs);
        
        require(
            !_lastUpdate.timestamp.isZero(), 
            IWitPythErrors.PriceFeedNotFound()
        );
        
        require(
            _conditions.heartbeatSecs == 0
                || block.timestamp <= Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + _conditions.heartbeatSecs,
            IWitPythErrors.StalePrice()
        );

        return IWitPriceFeedsTypes.Price({
            exponent: _lastUpdate.exponent,
            deltaPrice: _lastUpdate.deltaPrice,
            price: _lastUpdate.emaPrice > 0 ? _lastUpdate.emaPrice : _lastUpdate.price,
            timestamp: _lastUpdate.timestamp,
            trail: _lastUpdate.trail
        });
    }

    function getPriceNotOlderThan(IWitPriceFeedsTypes.ID4 id4, uint24 age)
        public view 
        returns (IWitPriceFeedsTypes.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id4);
        PriceData memory _lastUpdate = fetchLastUpdate(__record, id4, age);

        require(
            !_lastUpdate.timestamp.isZero(), 
            IWitPythErrors.PriceFeedNotFound()
        );

        require(
            block.timestamp <= Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + age,
            IWitPythErrors.StalePrice()
        );

        return IWitPriceFeedsTypes.Price({
            exponent: _lastUpdate.exponent,
            deltaPrice: _lastUpdate.deltaPrice,
            price: _lastUpdate.emaPrice > 0 ? _lastUpdate.emaPrice : _lastUpdate.price,
            timestamp: _lastUpdate.timestamp,
            trail: _lastUpdate.trail
        });
    }

    function getPriceUnsafe(IWitPriceFeedsTypes.ID4 id4)
        public view 
        returns (IWitPriceFeedsTypes.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id4);
        PriceData memory _lastUpdate = fetchLastUpdate(__record, id4, 0);

        return IWitPriceFeedsTypes.Price({
            exponent: _lastUpdate.exponent,
            deltaPrice: _lastUpdate.deltaPrice,
            price: _lastUpdate.emaPrice > 0 ? _lastUpdate.emaPrice : _lastUpdate.price,
            timestamp: _lastUpdate.timestamp,
            trail: _lastUpdate.trail
        });
    }

    function lookupPriceFeedInfo(IWitPriceFeedsTypes.ID4 id4) public view returns (IWitPriceFeedsTypes.PriceFeedInfo memory _info) {
        PriceFeed storage self = seekPriceFeed(id4);
        _info = IWitPriceFeedsTypes.PriceFeedInfo({
            id: data().ids[self.index],
            exponent: self.exponent,
            symbol: self.symbol,
            mapper: lookupPriceFeedMapper(id4),
            oracle: lookupPriceFeedOracle(id4),
            updateConditions: self.updateConditions,
            lastUpdate: getPriceUnsafe(id4)
        });
    }

    function lookupPriceFeedMapper(IWitPriceFeedsTypes.ID4 id4) public view returns (IWitPriceFeedsTypes.PriceFeedMapper memory _mapper) {
        PriceFeed storage self = seekPriceFeed(id4);
        _mapper.class = self.mapper;
        if (_mapper.class != IWitPriceFeedsTypes.Mappers.None) {
            IWitPriceFeedsTypes.ID4[] memory _deps = deps(id4);
            string[] memory _symbols = new string[](_deps.length);
            for (uint8 _ix; _ix < _symbols.length; ++ _ix) {
                _symbols[_ix] = seekPriceFeed(_deps[_ix]).symbol;
            }
            _mapper.deps = _symbols;
        }
    }

    function lookupPriceFeedOracle(IWitPriceFeedsTypes.ID4 id4) public view returns (IWitPriceFeedsTypes.PriceFeedOracle memory _oracle) {
        PriceFeed storage self = seekPriceFeed(id4);
        _oracle.class = self.oracle;
        _oracle.target = self.oracleAddress;
        _oracle.sources = self.oracleSources;
    }

    function lookupPriceFeedQoS(
            IWitPriceFeedsTypes.ID4 id4, 
            IWitOracleRadonRegistry registry
        ) 
        public view 
        returns (IWitPriceFeedsTypes.PriceFeedQoS memory _qos)
    {
        PriceFeed storage self = seekPriceFeed(id4);
        IWitPriceFeedsTypes.PriceUpdateConditions memory _updateConditions = self.updateConditions;
        
        if (
            self.oracle == IWitPriceFeedsTypes.Oracles.Witnet 
                && self.oracleSources != bytes32(0)
        ) {
            _qos.witnessingCommitteeSize = _updateConditions.minWitnesses;
            if (self.oracleAddress == address(0)) {
                _qos.computesEMA = _updateConditions.computeEMA;
                _qos.maxDeviation1000 = _updateConditions.maxDeviation1000;
                _qos.maxSecsBetweenUpdates = _updateConditions.heartbeatSecs;
                _qos.minSecsBetweenUpdates = _updateConditions.cooldownSecs;
                _qos.numTrackableDataSources = registry.lookupRadonRequestRetrievalsCount(
                    Witnet.RadonHash.wrap(self.oracleSources)
                );
            } else {
                // no updateConditions stored for Witnet-oraclized price feeds
                _qos = IWitPriceFeeds(self.oracleAddress).lookupPriceFeedQualityMetrics(
                    IWitPriceFeedsTypes.ID4.wrap(bytes4(self.oracleSources))
                );
            }
        } else if (self.mapper == IWitPriceFeedsTypes.Mappers.None) {
            // no updateConditions stored for mapped price feeds
            _qos.computesEMA = _updateConditions.computeEMA;
            _qos.maxSecsBetweenUpdates = _updateConditions.heartbeatSecs;
            _qos.minSecsBetweenUpdates = _updateConditions.cooldownSecs;
        }

        if (self.mapper != IWitPriceFeedsTypes.Mappers.None) {
            if (
                self.mapperDeps != bytes32(0)
                    && (
                        self.mapper == IWitPriceFeedsTypes.Mappers.Fallback 
                            || self.mapper == IWitPriceFeedsTypes.Mappers.Hottest
                    ) 
            ) {
                _qos.numFallbackOracles = _countBaseDeps(self.mapperDeps) - 1;
            } 
            _qos.numMappedPriceFeeds = _countDeepDeps(self.mapperDeps);
            _foldQoS(_qos, registry, self.mapperDeps);
        }
    }

    function lookupPriceFeedRadonHash(IWitPriceFeedsTypes.ID4 id4) public view returns (Witnet.RadonHash _radonHash) {
        PriceFeed storage self = seekPriceFeed(id4);
        if (self.oracle == IWitPriceFeedsTypes.Oracles.Witnet) {
            return Witnet.RadonHash.wrap(self.oracleSources);    
        }
    }

    
    // ================================================================================================================
    // --- Price-feed admin methods -----------------------------------------------------------------------------------

    function removePriceFeed(IWitPriceFeedsTypes.ID4 id4, bool recursively) public {
        PriceFeed storage self = seekPriceFeed(id4);
        if (self.settled()) {
            IWitPriceFeedsTypes.ID4[] memory _reverseDeps = data().reverseDeps[id4];
            require(
                recursively
                    || _reverseDeps.length == 0,
                "cannot remove if mapped from others"  
            );

            // recursively remove reverse dependencies, if any
            // (i.e. other price feeds that rely directly or indirectly on this one)
            for (uint _ix; _ix < _reverseDeps.length; ++ _ix) {
                removePriceFeed(_reverseDeps[_ix], recursively);
            }
            delete data().reverseDeps[id4];

            // remove from array of supported price feeds
            uint _popIndex = data().ids.length - 1;
            if (self.index < _popIndex) {
                IWitPyth.ID _popID = data().ids[_popIndex];
                PriceFeed storage __last = seekPriceFeed(_intoID4(_popID));
                __last.index = self.index;
                data().ids[self.index] = _popID;
            }
            data().ids.pop();

            // delete all metadata, but the update conditions
            Witnet.RadonHash _radonHash = Witnet.RadonHash.wrap(self.oracleSources);       
            if (!_radonHash.isZero() && self.oracle == IWitPriceFeedsTypes.Oracles.Witnet) {
                data().reverseIds[_radonHash] = IWitPriceFeedsTypes.ID4.wrap(0);
            }
            delete data().records[id4].lastUpdate;
            delete data().records[id4];
        }
    }

    function settlePriceFeedFootprint() public returns (bytes4 _footprint) {
        _footprint = _computePriceFeedsFootprint();
        data().footprint = _footprint;
    }

    function settlePriceFeedMapper(
            string calldata symbol,
            int8 exponent,
            IWitPriceFeedsTypes.Mappers mapper,
            string[] calldata mapperDeps
        )
        public
        returns (bytes4)
    {
        require(
            uint8(mapper) > uint8(IWitPriceFeedsTypes.Mappers.None)
                && uint8(mapper) <= uint8(IWitPriceFeedsTypes.Mappers.Inverse), 
            "invalid mapper"
        );
        IWitPriceFeedsTypes.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(!__record.settled(), "already settled");
        bytes32 _mapperDeps;
        for (uint _ix; _ix < mapperDeps.length; _ix ++) {
            bytes4 _id4 = bytes4(hash(mapperDeps[_ix]));
            PriceFeed storage __depsFeed = seekPriceFeed(IWitPriceFeedsTypes.ID4.wrap(_id4));
            require(__depsFeed.settled(), string(abi.encodePacked(
                "unsupported dependency: ",
                mapperDeps[_ix]
            )));
            _mapperDeps |= (bytes32(_id4) >> (32 * _ix));
            data().reverseDeps[IWitPriceFeedsTypes.ID4.wrap(_id4)].push(id4);
        }
        __record.settleMapper(
            exponent, 
            mapper, 
            _mapperDeps
        );
        
        // smoke test: force the transaction to revert, should there be any dependency loopback:
        getPriceUnsafe(id4);

        // recompute and return the new price feeds footprint:
        return settlePriceFeedFootprint();
    }

    function settlePriceFeedOracle(
            string calldata symbol,
            int8 exponent,
            IWitPriceFeedsTypes.Oracles oracle,
            address oracleAddress,
            bytes32 oracleSources
        )
        public
        returns (bytes4)
    {
        require(
            uint8(oracle) >= uint8(IWitPriceFeedsTypes.Oracles.Witnet)
                && uint8(oracle) <= uint8(IWitPriceFeedsTypes.Oracles.Pyth), 
            "invalid oracle"
        );
        IWitPriceFeedsTypes.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(!__record.settled(), "already settled");
        require(oracleAddress.code.length > 0, "inexistent oracle");
        __record.settleOracle(
            exponent,
            oracle,
            oracleAddress,
            oracleSources
        );

        // smoke test: force the transaction to revert, if providing bad sources or target address
        getPriceUnsafe(id4);

        // recompute and return the new price feeds footprint:
        return settlePriceFeedFootprint();
    }

    function settlePriceFeedRadonBytecode(
            string calldata symbol,
            bytes calldata radonBytecode,
            int8 exponent,
            IWitOracleRadonRegistry registry
        )
        public
        returns (bytes4 _footprint, Witnet.RadonHash _radonHash)
    {
        IWitPriceFeedsTypes.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(address(registry) != address(0), "no radon registry");
        _radonHash = registry.hashOf(radonBytecode);
        __record.settleOracle(
            exponent, 
            IWitPriceFeedsTypes.Oracles.Witnet,
            address(this),
            Witnet.RadonHash.unwrap(_radonHash)
        );
        require(
            IWitPriceFeedsTypes.ID4.unwrap(data().reverseIds[_radonHash]) == bytes4(0), 
            "repeated rad hash"
        );
        data().reverseIds[_radonHash] = id4;
        _footprint = settlePriceFeedFootprint();
    }

    function settlePriceFeedRadonHash(
            string calldata symbol,
            Witnet.RadonHash radonHash,
            int8 exponent,
            IWitOracleRadonRegistry registry
        )
        public
        returns (bytes4)
    {
        IWitPriceFeedsTypes.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(address(registry) != address(0), "no radon registry");
        require(registry.isVerifiedRadonRequest(radonHash), "unverified sources");
        __record.settleOracle(
            exponent, 
            IWitPriceFeedsTypes.Oracles.Witnet,
            address(this),
            Witnet.RadonHash.unwrap(radonHash)
        );
        require(
            IWitPriceFeedsTypes.ID4. unwrap(data().reverseIds[radonHash]) == bytes4(0), 
            "repeated rad hash"
        );
        data().reverseIds[radonHash] = id4;
        return settlePriceFeedFootprint();
    }

    function toString(IWitPriceFeedsTypes.Mappers mapper) public pure returns (string memory) {
        if (mapper == IWitPriceFeedsTypes.Mappers.None) {
            return "None";
        } else if (mapper == IWitPriceFeedsTypes.Mappers.Product) {
            return "Product";
        } else if (mapper == IWitPriceFeedsTypes.Mappers.Fallback) {
            return "Fallback";
        } else if (mapper == IWitPriceFeedsTypes.Mappers.Hottest) {
            return "Hottest";
        } 
        revert("unsupported mapper");
    }

    function toString(IWitPriceFeedsTypes.Oracles oracle) public pure returns (string memory) {
        if (oracle == IWitPriceFeedsTypes.Oracles.Witnet) {
            return "Wit/Oracle";
        } else if (oracle == IWitPriceFeedsTypes.Oracles.ERC2362) {
            return "ADO/ERC2362";
        } else if (oracle == IWitPriceFeedsTypes.Oracles.Chainlink) {
            return "ChainlinkAggregatorV3";
        } else if (oracle == IWitPriceFeedsTypes.Oracles.Pyth) {
            return "IPyth";
        }
        revert("unsupported oracle");
    }

    
    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    uint256 private constant WAD = 1e18;
    uint256 private constant X_MAX = 1e18;
    uint256 private constant C120 = 120 * WAD;

    function computeEMA(uint256 dt, uint256 tau, uint256 nextPrice, uint256 lastEmaPrice)
        internal pure
        returns (uint64 ema)
    {
        if (lastEmaPrice == 0) {
            return uint64(nextPrice);
        }
        
        // ------------------------------------------------------
        // x = dt / tau (1e18 WAD)
        //
        uint256 x = (dt * WAD) / tau;

        // ------------------------------------------------------
        // Branchless clamp: x <= X_MAX
        //
        // x_sat = x if x <= X_MAX
        // x_sat = X_MAX if x > X_MAX
        //
        int256 diff = int256(x) - int256(X_MAX);
        uint256 mask = uint256(diff >> 255);
        uint256 x_sat = (x & mask) | (X_MAX & ~mask);

        // ------------------------------------------------------
        // Compute exp(-x_sat) using [5/5] Pade
        //
        // P(x) = 120 - 60x + 12x^2 - x^3
        // Q(x) = 120 + 60x + 12x*2 + x^3
        //
        uint256 x2 = (x_sat * x_sat) / WAD;
        uint256 x3 = (x2 * x_sat) / WAD;

        uint256 P_x = C120 - 60 * x_sat + 12 * x2 - x3;
        uint256 Q_x = C120 + 60 * x_sat + 12 * x2 + x3;

        uint256 Q_safe = Q_x | 1; // ensure non-zero denominator
        uint256 exp_neg = (P_x * WAD) / Q_safe;

        // ------------------------------------------------------
        // α = 1 - exp(-x)
        //
        uint256 alpha = WAD - exp_neg;

        // ------------------------------------------------------
        // nextEma = α·nextPrice + (1−α).lastEmaPrice
        //
        return uint64(
            (alpha * nextPrice) / WAD 
                + (exp_neg * lastEmaPrice) / WAD
        );
    }

    /// @notice Returns storage pointer to where Storage data is located. 
    function data() internal pure returns (Storage storage _ptr) {
        assembly {
            _ptr.slot := _WIT_FEEDS_DATA_SLOTHASH
        }
    }

    /// @notice Returns array of price feed ids from which given feed's value depends.
    /// @dev Returns empty array on either unsupported or not-routed feeds.
    /// @dev The maximum number of dependencies is hard-limited to 8, as to limit number
    /// @dev of SSTORE operations (`__storage().records[feedId].solverDepsFlag`), 
    /// @dev no matter the actual number of depending feeds involved.
    function deps(IWitPriceFeedsTypes.ID4 self) internal view returns (IWitPriceFeedsTypes.ID4[] memory _deps) {
        bytes32 _solverDepsFlag = data().records[self].mapperDeps;
        _deps = new IWitPriceFeedsTypes.ID4[](8);
        uint _len;
        for (_len; _len < 8; ++ _len) {
            bytes4 _id4 = bytes4(_solverDepsFlag);
            if (_id4 == 0) {
                break;
            } else {
                _deps[_len] = IWitPriceFeedsTypes.ID4.wrap(_id4);
                _solverDepsFlag <<= 32;
            }
        }
        assembly {
            // reset length to actual number of dependencies:
            mstore(_deps, _len)
        }
    }

    function equals(IWitPriceFeedsTypes.ID4 a, IWitPriceFeedsTypes.ID4 b) internal pure returns (bool) {
        return (
            IWitPriceFeedsTypes.ID4.unwrap(a)
                == IWitPriceFeedsTypes.ID4.unwrap(b)
        );
    }

    function hash(string memory symbol) internal pure returns (bytes32) {
        return keccak256(abi.encode(symbol));
    }

    function isZero(IWitPriceFeedsTypes.ID4 id4) internal pure returns (bool) {
        return IWitPriceFeedsTypes.ID4.unwrap(id4) == 0;
    }

    function seekPriceFeed(IWitPriceFeedsTypes.ID4 id4) internal view returns (PriceFeed storage) {
        return data().records[id4];
    }

    function settled(PriceFeed storage self) internal view returns (bool) {
        return(
            self.oracleSources != bytes32(0)
                || uint8(self.mapper) != 0
                || self.oracleAddress != address(0)
        );
    }

    function settleMapper(
            PriceFeed storage self, 
            int8 exponent,
            IWitPriceFeedsTypes.Mappers mapper, 
            bytes32 mapperDeps
        )
        internal
    {
        require(!self.settled(), "already settled");
        self.exponent = exponent;
        self.mapper = mapper;
        self.mapperDeps = mapperDeps;
    }

    function settleOracle(
            PriceFeed storage self,
            int8 exponent,
            IWitPriceFeedsTypes.Oracles oracle,
            address oracleAddress,
            bytes32 oracleSources
        )
        internal
    {
        require(!self.settled(), "already settled");
        self.exponent = exponent;
        self.oracle = oracle;
        self.oracleAddress = oracleAddress;
        self.oracleSources = oracleSources;
    }

    function toERC165Id(IWitPriceFeedsTypes.Oracles oracle) public pure returns (bytes4) {
        if (oracle == IWitPriceFeedsTypes.Oracles.Witnet) {
            return type(IWitOracle).interfaceId;
        
        } else if (oracle == IWitPriceFeedsTypes.Oracles.ERC2362) {
            return type(IERC2362).interfaceId;
        
        } else if (oracle == IWitPriceFeedsTypes.Oracles.Chainlink) {
            return type(IChainlinkAggregatorV3).interfaceId;
        
        } else if (oracle == IWitPriceFeedsTypes.Oracles.Pyth) {
            return type(IWitPyth).interfaceId;
        
        } else {
            return 0x0;
        }
    }


    // ================================================================================================================
    // --- Private methods --------------------------------------------------------------------------------------------

    function _coalesceQoS(
            IWitPriceFeedsTypes.PriceFeedQoS memory self,
            IWitPriceFeedsTypes.PriceFeedQoS memory next
        )
        private pure
    {
        if (!self.computesEMA) {
            // computes EMA if at least one in the hierarchy computes EMA:
            self.computesEMA = next.computesEMA;
        }
        if (
            self.maxDeviation1000 > 0 
                && next.maxDeviation1000 > 0 
                && self.maxDeviation1000 < next.maxDeviation1000
        ) {
            // takes the greatest of all max deviations, among all that have it set:
            self.maxDeviation1000 = next.maxDeviation1000;
        } else {
            // final max deviation will be 0 (i.e. oo), if at least one in hierarchy has none set:
            self.maxDeviation1000 = 0;
        }
        if (
            next.maxSecsBetweenUpdates > 0
                && self.maxSecsBetweenUpdates > next.maxSecsBetweenUpdates
        ) {
            // take the lowest of all set-up heartbeats:
            self.maxSecsBetweenUpdates = next. maxSecsBetweenUpdates;
        }
        if (
            next.minSecsBetweenUpdates > 0 
                && self.minSecsBetweenUpdates > next.minSecsBetweenUpdates
        ) {
            // take the lowest of all set-up cooldowns:
            self.minSecsBetweenUpdates = next.minSecsBetweenUpdates;
        }
        if (
            next.witnessingCommitteeSize > 0
                && self.witnessingCommitteeSize > next.witnessingCommitteeSize
        ) {
            // take the smallest of the witnessing commitees, among all that have it set:
            self.witnessingCommitteeSize = next.witnessingCommitteeSize;
        }
        // take the sum of all set-up fallback oracles:
        self.numFallbackOracles += next.numFallbackOracles;
        // take the sum of all trackable data sources:
        self.numTrackableDataSources += next.numTrackableDataSources;
    }

    /// @dev Quick count of mapped price feeds.
    function _countBaseDeps(bytes32 mapperDeps) private pure returns (uint8 _count) {
        for (; bytes4(mapperDeps) != 0; mapperDeps <<= 32) {
            ++ _count;
        }
    }

    /// @dev Recursively sum up the number of deps for each price feed in `mapperDeps`.
    function _countDeepDeps(bytes32 mapperDeps) private view returns (uint16 _count) {
        for (; bytes4(mapperDeps) != 0; mapperDeps <<= 32) {
            _count += 1 + _countDeepDeps(
                seekPriceFeed(IWitPriceFeedsTypes.ID4.wrap(bytes4(mapperDeps))).mapperDeps
            );
        }
    }

    function _completeInitCode(bytes memory initcode, bytes memory params) private pure returns (bytes memory) {
        return abi.encodePacked(
            initcode,
            params
        );
    }

    function _computePriceFeedsFootprint() private view returns (bytes4 _footprint) {
        uint _totalIds = data().ids.length;
        if (_totalIds > 0) {
            _footprint = _footprintOf(_intoID4(data().ids[0]));
            for (uint _ix = 1; _ix < _totalIds; ++ _ix) {
                _footprint ^= _footprintOf(_intoID4(data().ids[_ix]));
            }
        }
    }

    function _determineCreate2Address(bytes memory initcode, bytes memory params) private view returns (address) {
        return address(
            uint160(uint(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    bytes32(0),
                    keccak256(_completeInitCode(initcode, params))
                )
            )))
        );
    }

    function _fetchLastUpdateFromProduct(
            IWitPriceFeedsTypes.ID4 id4, 
            uint24 heartbeat, 
            int8 exponent, 
            bool inverse
        )
        internal view 
        returns (PriceData memory _lastUpdate)
    {
        IWitPriceFeedsTypes.ID4[] memory _deps = deps(id4);
        int[3] memory _regs;
        // _regs[0] -> _lastPrice
        // _regs[1] -> _lastEmaPrice
        // _regs[2] -> _exponent
        unchecked {
            for (uint _ix; _ix < _deps.length; ++ _ix) {
                PriceData memory _depLastUpdate = fetchLastUpdate(seekPriceFeed(_deps[_ix]), _deps[_ix], heartbeat);
                if (_ix == 0) {
                    if (_depLastUpdate.emaPrice > 0) {
                        _regs[1] = int64(_depLastUpdate.emaPrice);
                    } else {
                        _regs[0] = int64(_depLastUpdate.price);
                    }
                    _lastUpdate.timestamp = _depLastUpdate.timestamp;
                    _lastUpdate.trail = _depLastUpdate.trail;
                    
                } else {
                    if (_regs[1] > 0) {
                        _regs[1] *= int64(_depLastUpdate.emaPrice);
                    } else {
                        _regs[0] *= int64(_depLastUpdate.price);
                    }
                    if (_lastUpdate.timestamp.gt(_depLastUpdate.timestamp)) {
                        // on Product: timestamp belong to oldest of all deps
                        _lastUpdate.timestamp = _depLastUpdate.timestamp;
                        _lastUpdate.trail = _depLastUpdate.trail;
                    }
                }
                _regs[2] += inverse ? _depLastUpdate.exponent : - _depLastUpdate.exponent;
            }
        }
        _regs[2] += exponent;
        if (_regs[2] <= 0) {
            if (inverse) {
                uint _factor = 10 ** uint(-_regs[2]);
                if (_regs[1] > 0) {
                    _lastUpdate.emaPrice = uint64(_factor / uint(_regs[1]));
                } else if (_regs[0] > 0) {
                    _lastUpdate.price = uint64(_factor / uint(_regs[0]));
                } else {
                    _lastUpdate.price = 0; // avoid unhandled reverts
                }
            } else {
                uint _divisor = 10 ** uint(-_regs[2]);
                if (_regs[1] > 0) {
                    _lastUpdate.emaPrice = uint64(uint(_regs[1]) / _divisor);
                } else {
                    _lastUpdate.price = uint64(uint(_regs[0]) / _divisor);
                }
            }
        } else {
            uint _factor = 10 ** uint(_regs[2]);
            if (_regs[1] > 0) {
                _lastUpdate.emaPrice = uint64(uint(_regs[1]) * _factor);
            } else {
                _lastUpdate.price = uint64(uint(_regs[0]) * _factor);
            }
        }
        _lastUpdate.exponent = exponent;
    }

    function _fetchLastUpdateFromHottest(IWitPriceFeedsTypes.ID4 id4, uint24 heartbeat, int8 exponent)
        internal view 
        returns (PriceData memory _lastUpdate)
    {
        IWitPriceFeedsTypes.ID4[] memory _deps = deps(id4);
        for (uint _ix; _ix < _deps.length; ++ _ix) {
            PriceData memory _depLastUpdate = fetchLastUpdate(seekPriceFeed(_deps[_ix]),  _deps[_ix], heartbeat);
            if (
                _ix == 0
                    || _depLastUpdate.timestamp.gt(_lastUpdate.timestamp)
            ) {
                _lastUpdate = _depLastUpdate;
            }
        }
        if (exponent < _lastUpdate.exponent) {
            _lastUpdate.price *= uint64(10 ** uint8(_lastUpdate.exponent - exponent));
            _lastUpdate.exponent = exponent;
        } else if (exponent > _lastUpdate.exponent) {
            _lastUpdate.price /= uint64(10 ** uint8(exponent - _lastUpdate.exponent));
            _lastUpdate.exponent = exponent;
        }
    }

    function _fetchLastUpdateFromFallback(IWitPriceFeedsTypes.ID4 id4, uint24 heartbeat, int8 exponent)
        internal view 
        returns (PriceData memory _lastUpdate)
    {
        IWitPriceFeedsTypes.ID4[] memory _deps = deps(id4);
        for (uint _ix; _ix < _deps.length; ++ _ix) {
            PriceData memory _depLastUpdate = fetchLastUpdate(seekPriceFeed(_deps[_ix]), _deps[_ix], heartbeat);
            if (
                heartbeat == 0
                    || Witnet.Timestamp.unwrap(_depLastUpdate.timestamp) > uint64(block.timestamp - heartbeat)
            ) {
                return _depLastUpdate;
            }
        }
        if (exponent < _lastUpdate.exponent) {
            _lastUpdate.price *= uint64(10 ** uint8(_lastUpdate.exponent - exponent));
            _lastUpdate.exponent = exponent;
        } else if (exponent > _lastUpdate.exponent) {
            _lastUpdate.price /= uint64(10 ** uint8(exponent - _lastUpdate.exponent));
            _lastUpdate.exponent = exponent;
        }
    }

    function _foldQoS(
            IWitPriceFeedsTypes.PriceFeedQoS memory qos,
            IWitOracleRadonRegistry registry,
            bytes32 mapperDeps
        ) 
        private view 
    {
        for (; bytes4(mapperDeps) != 0; mapperDeps <<= 32) {
            IWitPriceFeedsTypes.ID4 id4 = IWitPriceFeedsTypes.ID4.wrap(bytes4(mapperDeps));
            PriceFeed storage dependency = seekPriceFeed(id4);
            if (dependency.mapper == IWitPriceFeedsTypes.Mappers.None) {
               _coalesceQoS(qos, lookupPriceFeedQoS(id4, registry));
            } else {
               _foldQoS(qos, registry, dependency.mapperDeps);
            }
        }
    }

    function _footprintOf(IWitPriceFeedsTypes.ID4 id4) private view returns (bytes4) {
        WitPriceFeedsDataLib.PriceFeed storage self = seekPriceFeed(id4);
        if (self.oracleSources == bytes32(0)) {
            return self.mapper != IWitPriceFeedsTypes.Mappers.None ? (
                bytes4(keccak256(abi.encodePacked(
                    IWitPriceFeedsTypes.ID4.unwrap(id4), 
                    self.mapperDeps
                )))
            ) : (
                bytes4(keccak256(abi.encodePacked(
                    IWitPriceFeedsTypes.ID4.unwrap(id4), 
                    self.oracleAddress
                )))
            );

        } else {
            return bytes4(keccak256(abi.encodePacked(
                IWitPriceFeedsTypes.ID4.unwrap(id4), 
                self.oracleSources
            )));
        }
    }

    function _intoID4(IWitPyth.ID id) private pure returns (IWitPriceFeedsTypes.ID4) {
        return IWitPriceFeedsTypes.ID4.wrap(bytes4(IWitPyth.ID.unwrap(id)));
    }

    function _intoWitPythID(IWitPriceFeedsTypes.ID4 id4) private view returns (IWitPyth.ID) {
        return data().ids[data().records[id4].index];
    }

        function _intoPriceData(IWitPriceFeedsTypes.Price memory _price) internal pure returns (PriceData memory) {
        return PriceData({
            emaPrice: 0,
            price: _price.price,
            deltaPrice: _price.deltaPrice,
            timestamp: _price.timestamp,
            trail: _price.trail,
            exponent: _price.exponent
        });
    }

    function _intoEmaPriceData(IWitPriceFeedsTypes.Price memory _price) internal pure returns (PriceData memory) {
        return PriceData({
            emaPrice: _price.price,
            price: 0,
            deltaPrice: _price.deltaPrice,
            timestamp: _price.timestamp,
            trail: _price.trail,
            exponent: _price.exponent
        });
    }

    function _settlePriceFeedSymbol(string calldata symbol) private returns (IWitPriceFeedsTypes.ID4 id4) {
        bytes32 _id = hash(symbol);
        id4 = IWitPriceFeedsTypes.ID4.wrap(bytes4(_id));
        PriceFeed storage __record = seekPriceFeed(id4);
        if (
            keccak256(abi.encode(symbol))
                != keccak256(abi.encode(__record.symbol))
        ) {
            require(
                data().reverseDeps[id4].length == 0,
                "cannot refactor exisitng symbol if mapped by others"
            );
            __record.symbol = symbol;
            __record.index = uint32(data().ids.length);
            delete __record.lastUpdate;
        }
        if (!__record.settled()) {
            // add id to the list of supported price feeds, if not currently settled
            data().ids.push(IWitPyth.ID.wrap(_id));
        }
    }
}
