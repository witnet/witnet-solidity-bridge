// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "ado-contracts/contracts/interfaces/IERC2362.sol";

import "../libs/Witnet.sol";

import "../interfaces/IWitOracle.sol";
import "../interfaces/IWitOracleRadonRegistry.sol";
import "../interfaces/IWitPriceFeeds.sol";
import "../interfaces/IWitPriceFeedsAdmin.sol";
import "../interfaces/IWitPriceFeedsMappingSolver.sol";

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

    using WitPriceFeedsDataLib for IWitPriceFeeds.ID4;
    using WitPriceFeedsDataLib for PriceFeed;
    
    bytes32 private constant _WIT_FEEDS_DATA_SLOTHASH =
        /* keccak256("io.witnet.feeds.data") */
        0xe36ea87c48340f2c23c9e1c9f72f5c5165184e75683a4d2a19148e5964c1d1ff;

    struct Storage {
        IWitPyth.ID[] ids;
        mapping (IWitPriceFeeds.ID4 => PriceFeed) records;
        mapping (IWitPriceFeeds.ID4 => IWitPriceFeeds.ID4[]) reverseDeps;
        mapping (Witnet.RadonHash => IWitPriceFeeds.ID4) reverseIds;
        IWitPriceFeeds.UpdateConditions defaultUpdateConditions;
        IWitPriceFeedsAdmin.WitParams requiredWitParams;
        bytes4  footprint;
        bytes28 _0;
    }

    struct PriceData {
        /// @dev Exponentially moving average proportional to actual time since previous update.
        uint64 emaPrice;
        
        /// @dev Price attested on the Wit/Oracle blockchain.
        uint64 price;
        
        /// @dev How much the price varied since previous update.
        int56  deltaPrice;
        
        /// @dev Base-10 exponent to compute actual price.
        int8   exponent;

        /// @dev Timestamp at which the price was attested on the Wit/Oracle blockchain.
        Witnet.Timestamp timestamp;
    }

    struct Price {
        /// @dev Price data point to be read is just one single SLOAD.
        PriceData data;
        
        /// @dev Auditory track: attestation transaction hash on the Wit/Oracle blockchain.
        Witnet.TransactionHash track;
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
        IWitPriceFeeds.Mappers mapper;

        /// @dev Price feed's aggregator oracle type, if other than the Wit/Oracle.
        IWitPriceFeeds.Oracles oracle;

        /// @dev Price feed's aggregator oracle address, if other than the Wit/Oracle.
        address oracleAddress;

        /// @dev Unique ID identifying actual data sources and off-chain computations performed by 
        /// the selected oracle when retrieving a fresh update for this price feed 
        /// (e.g. Radon Request hash if oracle is the Wit/Oracle).
        bytes32 oracleSources;

        /// @dev 256-bit flag containing references up to 8x existing price feeds.
        bytes32 mapperDeps;

        /// @dev Price-feed specific update conditions, if other than defaults.
        IWitPriceFeeds.UpdateConditions updateConditions;

        /// @dev Last valid update data retrieved from the Wit/Oracle, if any.
        Price lastWitUpdate;
    }

    struct WitParams {
        uint16 minWitCommitteeSize;
        uint16 maxWitCommitteeSize;
    }


    // ================================================================================================================
    // --- Public methods ---------------------------------------------------------------------------------------------

    function fetchLastUpdate(
            PriceFeed storage self, 
            IWitPriceFeeds.ID4 id4,
            bool ema,
            bool fetchLastTrack,
            uint24 heartbeatSecs
        )
        public view 
        returns (
            PriceData memory _lastUpdateData,
            Witnet.TransactionHash _lastUpdateTrack
        )
    {
        IWitPriceFeeds.Mappers _mapper = self.mapper;
        if (_mapper == IWitPriceFeeds.Mappers.None) {
            
            IWitPriceFeeds.Oracles _oracle = self.oracle;
            if (_oracle == IWitPriceFeeds.Oracles.Witnet) {
                require(
                    self.oracleSources != bytes32(0), 
                    IWitPythErrors.PriceFeedNotFound()
                );
                _lastUpdateData = self.lastWitUpdate.data;
                if (fetchLastTrack) _lastUpdateTrack = self.lastWitUpdate.track;

            } else if (_oracle == IWitPriceFeeds.Oracles.ERC2362) {
                require(!ema, "no EMA on ERC2362's");
                (int _value, uint _timestamp,) = IERC2362(self.oracleAddress).valueFor(self.oracleSources);
                _lastUpdateData.price = uint64(int64(_value));
                _lastUpdateData.timestamp = Witnet.Timestamp.wrap(uint64(_timestamp));
                _lastUpdateData.exponent = self.exponent;

            } else if (_oracle == IWitPriceFeeds.Oracles.Chainlink) {
                require(!ema, "no EMA on Chainlink's");
                (uint80 _timestamp, int _value,,,) = IChainlinkAggregatorV3(self.oracleAddress).latestRoundData();
                _lastUpdateData.price = uint64(int64(_value));
                _lastUpdateData.timestamp = Witnet.Timestamp.wrap(uint64(_timestamp));
                _lastUpdateData.exponent = self.exponent;
            
            } else if (_oracle == IWitPriceFeeds.Oracles.Pyth) {
                IWitPyth.Price memory _price;
                if (ema) {
                    _price = IWitPyth(self.oracleAddress).getEmaPriceUnsafe(IWitPyth.ID.wrap(self.oracleSources));
                } else {
                    _price = IWitPyth(self.oracleAddress).getPriceUnsafe(IWitPyth.ID.wrap(self.oracleSources));
                }
                _lastUpdateData.price = _price.price;
                _lastUpdateData.deltaPrice = int56(uint56((_price.price * _price.conf) / 1000));
                _lastUpdateData.timestamp = _price.publishTime;
                _lastUpdateData.exponent = int8(_price.expo);

            } else {
                revert("unsupported oracle");
            }
        
        } else {    
            if (_mapper == IWitPriceFeeds.Mappers.Product) {
                _lastUpdateData = fetchLastUpdateFromProduct(id4, ema, heartbeatSecs, self.exponent);

            } else if (_mapper == IWitPriceFeeds.Mappers.Hottest) {
                return fetchLastUpdateFromHottest(id4, ema, heartbeatSecs, fetchLastTrack);
            
            } else if (_mapper == IWitPriceFeeds.Mappers.Fallback) {
                return fetchLastUpdateFromFallback(id4, ema, heartbeatSecs, fetchLastTrack);
            
            } else {
                revert("unsupported mapper");
            }
        }
    }

    function getPrice(
            IWitPriceFeeds.ID4 id4, 
            bool ema
        )
        public view 
        returns (IWitPyth.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id4);
        IWitPriceFeeds.UpdateConditions memory _updateConditions = coalesce(__record.updateConditions);
        (PriceData memory _lastUpdate, Witnet.TransactionHash _lastUpdateTrack) = fetchLastUpdate(
                __record,
                id4, 
                ema,
                true,
                _updateConditions.heartbeatSecs
            );
        
        if (!_lastUpdate.timestamp.isZero()) {
            if (_updateConditions.maxDeviation1000 > 0) {
                require(
                    _computeDeviation1000(_lastUpdate.price, _lastUpdate.deltaPrice)
                        <= _updateConditions.maxDeviation1000,
                    IWitPythErrors.DeviantPrice()
                );
            }
            if (
                _updateConditions.heartbeatSecs == 0 
                    || block.timestamp < Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + _updateConditions.heartbeatSecs
            ) {
                if (!ema || _updateConditions.computeEma) {
                    return IWitPyth.Price({
                        price: ema ? _lastUpdate.emaPrice : _lastUpdate.price,
                        conf: uint64(
                            _lastUpdate.deltaPrice >= 0 
                                ? int64(_lastUpdate.deltaPrice) 
                                : int64(-_lastUpdate.deltaPrice)
                        ),
                        expo: _lastUpdate.exponent,
                        publishTime: _lastUpdate.timestamp,
                        track: _lastUpdateTrack
                    });
                } else {
                    revert IWitPythErrors.InvalidGovernanceTarget();
                }
            } else {
                revert IWitPythErrors.StalePrice();
            }
        
        } else {
            revert IWitPythErrors.NoFreshUpdate();
        }
    }

    function getPriceNotOlderThan(IWitPriceFeeds.ID4 id4, bool ema, uint24 age)
        public view 
        returns (IWitPyth.Price memory)
    {
        (PriceData memory _lastUpdate, Witnet.TransactionHash _lastUpdateTrack) = fetchLastUpdate(
            seekPriceFeed(id4),
            id4, 
            ema,
            true,
            age
        );
        
        if (!_lastUpdate.timestamp.isZero()) {
            if (
                block.timestamp < Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + age
            ) {
                return IWitPyth.Price({
                    price: ema ? _lastUpdate.emaPrice : _lastUpdate.price,
                    conf: uint64(
                        _lastUpdate.deltaPrice >= 0 
                            ? int64(_lastUpdate.deltaPrice) 
                            : int64(-_lastUpdate.deltaPrice)
                    ),
                    expo: _lastUpdate.exponent,
                    publishTime: _lastUpdate.timestamp,
                    track: _lastUpdateTrack
                });
            } else {
                revert IWitPythErrors.StalePrice();
            }

        } else {
            revert IWitPythErrors.NoFreshUpdate();
        }
    }

    function getPriceUnsafe(IWitPriceFeeds.ID4 id4, bool ema)
        public view 
        returns (IWitPyth.Price memory)
    {
        (PriceData memory _lastUpdate, Witnet.TransactionHash _lastUpdateTrack) = fetchLastUpdate(
            seekPriceFeed(id4),
            id4, 
            ema,
            true,
            0
        );
        
        if (!_lastUpdate.timestamp.isZero()) {
            return IWitPyth.Price({
                price: ema ? _lastUpdate.emaPrice : _lastUpdate.price,
                conf: uint64(
                    _lastUpdate.deltaPrice >= 0 
                        ? int64(_lastUpdate.deltaPrice) 
                        : int64(-_lastUpdate.deltaPrice)
                ),
                expo: _lastUpdate.exponent,
                publishTime: _lastUpdate.timestamp,
                track: _lastUpdateTrack
            });

        } else {
            revert IWitPythErrors.NoFreshUpdate();
        }
    }

    function parsePriceFeedUpdates(
            IWitOracle witOracle,
            bytes[] calldata updates,
            IWitPyth.ID[] calldata ids,
            Witnet.Timestamp minTimestamp,
            Witnet.Timestamp maxTimestamp,
            bool checkUniqueness
        )
        public view
        returns (IWitPyth.PriceFeed[] memory _priceFeeds)
    {
        _priceFeeds = new IWitPyth.PriceFeed[](ids.length);
        unchecked {
            IWitPriceFeedsAdmin.WitParams memory _required = data().requiredWitParams;
            for (uint _ix = 0; _ix < updates.length; _ix ++) {
                // deserialize actual data push report and authenticity proof:
                (Witnet.DataPushReport memory _report, bytes memory _proof) = abi.decode(
                    updates[_ix], 
                    (Witnet.DataPushReport, bytes)
                );

                // check that governance target rules are met:
                require(
                    _report.witDrSLA.witCommitteeSize >= _required.minWitCommitteeSize
                        && (
                            _required.maxWitCommitteeSize == 0
                                || _report.witDrSLA.witCommitteeSize <= _required.maxWitCommitteeSize
                        ),
                    IWitPythErrors.InvalidGovernanceTarget()
                );

                // revert if any of the allegedly fresh update refers a radonHash 
                // that's not actually settled on any of the supported price-feeds:
                IWitPriceFeeds.ID4 _priceId = data().reverseIds[_report.witRadonHash];
                require(
                    IWitPriceFeeds.ID4.unwrap(_priceId) != 0, 
                    IWitPythErrors.InvalidUpdateDataSource()
                );

                // revert if order of provided `updates` does not match the order of `ids`
                require(
                    IWitPriceFeeds.ID4.unwrap(_priceId) == bytes4(IWitPyth.ID.unwrap(ids[_ix])),
                    IWitPythErrors.InvalidArgument()
                );

                // parse and validate autheticity of every update report:
                Witnet.DataResult memory _data = witOracle.parseDataReport(_report, _proof);

                // determine whether to add update report into output array:
                PriceFeed storage __record = seekPriceFeed(_priceId);
                PriceData memory _prevData = __record.lastWitUpdate.data;
                if (
                    _data.timestamp.egt(minTimestamp)
                        && _data.timestamp.elt(maxTimestamp)
                        && (!checkUniqueness || minTimestamp.gt(_prevData.timestamp))
                ) {
                    _priceFeeds[_ix] = _intoWitPythPriceFeed(
                        _intoWitPythID(_priceId),
                        _data, 
                        _prevData,
                        IWitPriceFeeds.UpdateConditions({
                            computeEma: true,
                            cooldownSecs: 0,
                            heartbeatSecs: 0,
                            maxDeviation1000: 0
                        })
                    );
                }
            }
            // revert in case there was at least one price with no actual update within given range:
            for (uint _ix = 0; _ix < _priceFeeds.length; _ix ++) {
                require(
                    IWitPyth.ID.unwrap(_priceFeeds[_ix].id) != bytes32(0), 
                    IWitPythErrors.PriceFeedNotFoundWithinRange()
                );
            }
        }
    }

    function updatePriceFeed(
            IWitOracle witOracle, 
            IWitPriceFeeds.UpdateConditions memory defaultUpdateConditions,
            Witnet.DataPushReport calldata report, 
            bytes calldata proof
        )
        public
    {
        // revert if any of the allegedly fresh update refers a radonHash 
        // that's not actually settled on any of the supported price-feeds:
        IWitPriceFeeds.ID4 _id4 = data().reverseIds[report.witRadonHash];
        require(
            IWitPriceFeeds.ID4.unwrap(_id4) != 0, 
            IWitPythErrors.InvalidUpdateDataSource()
        );

        // roll-up wit/oracle proof and deserialize price update data,
        // as long as the update report is proven to be authentic:
        Witnet.DataResult memory _result = witOracle.pushDataReport(report, proof);

        // process price update:
        return pushDataResult(_result, defaultUpdateConditions, _id4);
    }

    
    // ================================================================================================================
    // --- Price-feed admin methods -----------------------------------------------------------------------------------

    function removePriceFeed(IWitPriceFeeds.ID4 id4, bool recursively) public {
        PriceFeed storage self = seekPriceFeed(id4);
        require(self.settled(), "unknown price feed");

        IWitPriceFeeds.ID4[] memory _reverseDeps = data().reverseDeps[id4];
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
        data().ids[self.index] = data().ids[data().ids.length - 1];
        data().ids.pop();

        // reset all metadata, but the symbol
        self.exponent = 0;
        self.mapper = IWitPriceFeeds.Mappers.None;
        self.mapperDeps = bytes32(0);
        self.oracle = IWitPriceFeeds.Oracles.Witnet;
        self.oracleAddress = address(0); 
        Witnet.RadonHash _radonHash = Witnet.RadonHash.wrap(self.oracleSources);       
        if (!_radonHash.isZero()) {
            if (id4.equals(data().reverseIds[_radonHash])) {
                data().reverseIds[_radonHash] = IWitPriceFeeds.ID4.wrap(0);
            }
            self.oracleSources = bytes32(0);
        }
        delete self.updateConditions;
        delete self.lastWitUpdate;
    }

    function settlePriceFeedFootprint() public returns (bytes4 _footprint) {
        _footprint = _computePriceFeedsFootprint();
        data().footprint = _footprint;
    }

    function settlePriceFeedMapper(
            string calldata symbol,
            int8 exponent,
            IWitPriceFeeds.Mappers mapper,
            string[] calldata mapperDeps
        )
        public
        returns (bytes4)
    {
        require(
            uint8(mapper) > uint8(IWitPriceFeeds.Mappers.None)
                && uint8(mapper) <= uint8(IWitPriceFeeds.Mappers.Product), 
            "invalid mapper"
        );
        IWitPriceFeeds.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(!__record.settled(), "already settled");
        bytes32 _mapperDeps;
        for (uint _ix; _ix < mapperDeps.length; _ix ++) {
            bytes4 _id4 = bytes4(keccak256(bytes(mapperDeps[_ix])));
            PriceFeed storage __depsFeed = seekPriceFeed(IWitPriceFeeds.ID4.wrap(_id4));
            require(__depsFeed.settled(), "unsupported dependency");
            require(IWitPriceFeeds.ID4.unwrap(id4) != _id4, "dependency loop");
            _mapperDeps |= (bytes32(_id4) >> (32 * _ix));
            data().reverseDeps[IWitPriceFeeds.ID4.wrap(_id4)].push(id4);
        }
        __record.settleMapper(
            exponent, 
            mapper, 
            _mapperDeps
        );
        return settlePriceFeedFootprint();
    }

    function settlePriceFeedOracle(
            string calldata symbol,
            int8 exponent,
            IWitPriceFeeds.Oracles oracle,
            address oracleAddress,
            bytes32 oracleSources
        )
        public
        returns (bytes4)
    {
        require(
            uint8(oracle) > uint8(IWitPriceFeeds.Oracles.Witnet)
                && uint8(oracle) < uint8(IWitPriceFeeds.Oracles.Pyth), 
            "invalid oracle"
        );
        IWitPriceFeeds.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(!__record.settled(), "already settled");
        require(oracleAddress.code.length > 0, "inexistent oracle");
        __record.settleOracle(
            exponent,
            oracle,
            oracleAddress,
            oracleSources
        );
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
        IWitPriceFeeds.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(address(registry) != address(0), "no radon registry");
        _radonHash = registry.hashOf(radonBytecode);
        __record.settleWitOracle(exponent, _radonHash);
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
        IWitPriceFeeds.ID4 id4 = _settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        require(address(registry) != address(0), "no radon registry");
        require(registry.isVerifiedRadonRequest(radonHash), "unverified sources");
        __record.settleWitOracle(exponent, radonHash);
        return settlePriceFeedFootprint();
    }

    function toString(IWitPriceFeeds.Mappers mapper) public pure returns (string memory) {
        if (mapper == IWitPriceFeeds.Mappers.None) {
            return "None";
        } else if (mapper == IWitPriceFeeds.Mappers.Product) {
            return "Product";
        } else if (mapper == IWitPriceFeeds.Mappers.Fallback) {
            return "Fallback";
        } else if (mapper == IWitPriceFeeds.Mappers.Hottest) {
            return "Hottest";
        } 
        revert("unsupported mapper");
    }

    function toString(IWitPriceFeeds.Oracles oracle) public pure returns (string memory) {
        if (oracle == IWitPriceFeeds.Oracles.Witnet) {
            return "Wit/Oracle";
        } else if (oracle == IWitPriceFeeds.Oracles.ERC2362) {
            return "ADO/ERC2362";
        } else if (oracle == IWitPriceFeeds.Oracles.Chainlink) {
            return "ChainlinkAggregatorV3";
        } else if (oracle == IWitPriceFeeds.Oracles.Pyth) {
            return "IPyth";
        }
        revert("unsupported oracle");
    }

    
    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function coalesce(IWitPriceFeeds.UpdateConditions storage self) 
        internal view 
        returns (IWitPriceFeeds.UpdateConditions memory _updateConditions)
    {
        IWitPriceFeeds.UpdateConditions memory _self = self;
        if (
            _self.computeEma
                && _self.cooldownSecs > 0
                && _self.heartbeatSecs > 0
                && _self.maxDeviation1000 > 0
        ) {
            return _self;
        } else {
            IWitPriceFeeds.UpdateConditions memory _default = data().defaultUpdateConditions;
            return IWitPriceFeeds.UpdateConditions({
                computeEma: _self.computeEma || _default.computeEma,
                cooldownSecs:  _self.cooldownSecs == 0 ? _default.cooldownSecs : _self.cooldownSecs,
                heartbeatSecs: _self.heartbeatSecs == 0 ? _default.heartbeatSecs : _self.heartbeatSecs,
                maxDeviation1000: _self.maxDeviation1000 == 0 ? _default.maxDeviation1000 : _self.maxDeviation1000
            });
        }
    }

    function coalesce(IWitPriceFeeds.UpdateConditions storage self, IWitPriceFeeds.UpdateConditions memory _default) 
        internal pure
        returns (IWitPriceFeeds.UpdateConditions memory _updateConditions)
    {
        IWitPriceFeeds.UpdateConditions memory _self = self;
        return IWitPriceFeeds.UpdateConditions({
            computeEma: _self.computeEma || _default.computeEma,
            cooldownSecs:  _self.cooldownSecs == 0 ? _default.cooldownSecs : _self.cooldownSecs,
            heartbeatSecs: _self.heartbeatSecs == 0 ? _default.heartbeatSecs : _self.heartbeatSecs,
            maxDeviation1000: _self.maxDeviation1000 == 0 ? _default.maxDeviation1000 : _self.maxDeviation1000
        });
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
    function deps(IWitPriceFeeds.ID4 self) internal view returns (IWitPriceFeeds.ID4[] memory _deps) {
        bytes32 _solverDepsFlag = data().records[self].mapperDeps;
        _deps = new IWitPriceFeeds.ID4[](8);
        uint _len;
        for (_len; _len < 8; ++ _len) {
            bytes4 _id4 = bytes4(_solverDepsFlag);
            if (_id4 == 0) {
                break;
            } else {
                _deps[_len] = IWitPriceFeeds.ID4.wrap(_id4);
                _solverDepsFlag <<= 32;
            }
        }
        assembly {
            // reset length to actual number of dependencies:
            mstore(_deps, _len)
        }
    }

    function equals(IWitPriceFeeds.ID4 a, IWitPriceFeeds.ID4 b) internal pure returns (bool) {
        return (
            IWitPriceFeeds.ID4.unwrap(a)
                == IWitPriceFeeds.ID4.unwrap(b)
        );
    }

    function fetchLastUpdateFromProduct(
            IWitPriceFeeds.ID4 id4,
            bool ema,
            uint24 heartbeatSecs,
            int8 exponent
        )
        internal view 
        returns (PriceData memory _lastUpdateData)
    {
        IWitPriceFeeds.ID4[] memory _deps = deps(id4);
        PriceData memory _depLastUpdateData;
        int[4] memory _regs;
        // _regs[0] -> _lastPrice
        // _regs[1] -> _lastEmaPrice
        // _regs[2] -> _lastDeltaPrice
        // _regs[3] -> _decimals
        unchecked {
            for (uint _ix; _ix < _deps.length; ++ _ix) {
                (_depLastUpdateData,) = fetchLastUpdate(
                    seekPriceFeed(_deps[_ix]), 
                    _deps[_ix], 
                    ema,
                    false,
                    heartbeatSecs
                );
                if (_ix == 0) {
                    if (ema) {
                        _regs[1] = int64(_depLastUpdateData.emaPrice);
                    } else {
                        _regs[0] = int64(_depLastUpdateData.price);
                    }
                    _regs[2] = _depLastUpdateData.deltaPrice;
                    _lastUpdateData.timestamp = _depLastUpdateData.timestamp;
                    
                } else {
                    if (ema) {
                        _regs[1] *= int64(_depLastUpdateData.emaPrice);
                    } else {
                        _regs[0] *= int64(_depLastUpdateData.price);
                    }
                    _regs[2] *= _depLastUpdateData.deltaPrice;

                    if (_lastUpdateData.timestamp.gt(_depLastUpdateData.timestamp)) {
                        // on Product: timestamp belong to oldest of all deps
                        _lastUpdateData.timestamp = _depLastUpdateData.timestamp;
                    }
                }
                _regs[3] -= _depLastUpdateData.exponent;
            }
        }
        _regs[3] += exponent;
        if (_regs[3] > 0) {
            uint _divisor = 10 ** uint(_regs[3]);
            if (ema) {
                _lastUpdateData.emaPrice = uint64(uint(_regs[1]) / _divisor);
            } else {
                _lastUpdateData.price = uint64(uint(_regs[0]) / _divisor);
            }
            _lastUpdateData.deltaPrice = int56(_regs[2] / int(_divisor)); // ¿?
        
        } else {
            uint _factor = 10 ** uint(-_regs[3]);
            if (ema) {
                _lastUpdateData.emaPrice = uint64(uint(_regs[1]) * _factor);
            } else {
                _lastUpdateData.price = uint64(uint(_regs[0]) * _factor);
            }
            _lastUpdateData.deltaPrice = int56(_regs[2] * int(_factor));
        }
        _lastUpdateData.exponent = exponent;
    }

    function fetchLastUpdateFromHottest(
            IWitPriceFeeds.ID4 id4,
            bool ema,
            uint24 heartbeatSecs,
            bool fetchLastTrack
        )
        internal view 
        returns (
            PriceData memory _lastUpdateData,
            Witnet.TransactionHash _lastUpdateTrack
        )
    {
        IWitPriceFeeds.ID4[] memory _deps = deps(id4);
        PriceData memory _depLastUpdateData;
        Witnet.TransactionHash _depLastUpdateTrack;
        for (uint _ix; _ix < _deps.length; ++ _ix) {
            (_depLastUpdateData, _depLastUpdateTrack) = fetchLastUpdate(
                seekPriceFeed(_deps[_ix]), 
                _deps[_ix], 
                ema,
                fetchLastTrack,
                heartbeatSecs
            );
            if (_ix == 0) {
                _lastUpdateData = _depLastUpdateData;
                if (fetchLastTrack) {
                    _lastUpdateTrack = _depLastUpdateTrack;
                }
            } else if (_depLastUpdateData.timestamp.gt(_lastUpdateData.timestamp)) {
                // on Hottest: copy data from hottest of all deps
                _lastUpdateData = _depLastUpdateData;
                if (fetchLastTrack) {
                    _lastUpdateTrack = _depLastUpdateTrack;
                }
            }
        }
    }

    function fetchLastUpdateFromFallback(
            IWitPriceFeeds.ID4 id4,
            bool ema,
            uint24 heartbeatSecs,
            bool fetchLastTrack
        )
        internal view 
        returns (
            PriceData memory _lastUpdateData,
            Witnet.TransactionHash _lastUpdateTrack
        )
    {
        IWitPriceFeeds.ID4[] memory _deps = deps(id4);
        PriceData memory _depLastUpdateData;
        Witnet.TransactionHash _depLastUpdateTrack;
        for (uint _ix; _ix < _deps.length; ++ _ix) {
            (_depLastUpdateData, _depLastUpdateTrack) = fetchLastUpdate(
                seekPriceFeed(_deps[_ix]), 
                _deps[_ix], 
                ema,
                fetchLastTrack,
                heartbeatSecs
            );
            if (
                heartbeatSecs == 0 
                    || Witnet.Timestamp.unwrap(_depLastUpdateData.timestamp) > uint64(block.timestamp - heartbeatSecs)
            ) {
                _lastUpdateData = _depLastUpdateData;
                if (fetchLastTrack) _lastUpdateTrack = _depLastUpdateTrack;
                break;
            }
        }
    }

    function hash(string calldata symbol) internal pure returns (bytes32) {
        return keccak256(abi.encode(symbol));
    }

    function isZero(IWitPriceFeeds.ID4 id4) internal pure returns (bool) {
        return IWitPriceFeeds.ID4.unwrap(id4) == 0;
    }

        function pushDataResult(
            Witnet.DataResult memory result,
            IWitPriceFeeds.UpdateConditions memory defaultUpdateConditions,
            IWitPriceFeeds.ID4 id4
        )
        internal
    {
        PriceFeed storage __record = seekPriceFeed(id4);
        PriceData memory _lastUpdate = __record.lastWitUpdate.data;
        IWitPriceFeeds.UpdateConditions memory _updateConditions = coalesce(
            __record.updateConditions, 
            defaultUpdateConditions
        );
        
        // consider updating price-feed's last update only if reported value is more recent:
        if (
            Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + _updateConditions.cooldownSecs
                < Witnet.Timestamp.unwrap(result.timestamp)
        ) {
            // revert if any of the allegedly fresh updates actually contains 
            // no integer value:
            require(
                result.dataType == Witnet.RadonDataTypes.Integer
                    && result.status == Witnet.ResultStatus.NoErrors,
                IWitPythErrors.InvalidUpdateData()
            );

            // compute next data point based on `_result` and `_lastUpdate`
            __record.lastWitUpdate = _computeNextPrice(
                result, 
                _lastUpdate, 
                _updateConditions
            );
        }
    }

    function seekPriceFeed(IWitPriceFeeds.ID4 id4) internal view returns (PriceFeed storage) {
        return data().records[id4];
    }

    function settled(PriceFeed storage self) internal view returns (bool) {
        return(
            self.oracleSources != bytes32(0)
                || self.mapper != IWitPriceFeeds.Mappers.None
                || self.oracleAddress != address(0)
        );
    }

    function settleMapper(
            PriceFeed storage self, 
            int8 exponent,
            IWitPriceFeeds.Mappers mapper, 
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
            IWitPriceFeeds.Oracles oracle,
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

    function settleWitOracle(
            PriceFeed storage self, 
            int8 exponent,
            Witnet.RadonHash radonHash
        )
        internal
    {
        require(!self.settled(), "already settled");
        self.oracleSources = Witnet.RadonHash.unwrap(radonHash);
        self.exponent = exponent;
        self.lastWitUpdate.data.exponent = exponent;
    }

    function toERC165Id(IWitPriceFeeds.Oracles oracle) public pure returns (bytes4) {
        if (oracle == IWitPriceFeeds.Oracles.Witnet) {
            return type(IWitOracle).interfaceId;
        
        } else if (oracle == IWitPriceFeeds.Oracles.ERC2362) {
            return type(IERC2362).interfaceId;
        
        } else if (oracle == IWitPriceFeeds.Oracles.Chainlink) {
            return type(IChainlinkAggregatorV3).interfaceId;
        
        } else if (oracle == IWitPriceFeeds.Oracles.Pyth) {
            return type(IWitPyth).interfaceId;
        
        } else {
            return 0x0;
        }
    }


    // ================================================================================================================
    // --- Private methods --------------------------------------------------------------------------------------------

    function _computeDeviation1000(uint64 prevPrice, int deltaPrice) private pure returns (uint) {
        unchecked {
            int nextPrice = int64(prevPrice) + deltaPrice;
            return uint(
                1000 
                    * uint(deltaPrice >= 0 ? deltaPrice : -deltaPrice)
                    / uint(nextPrice >= 0 ? nextPrice : -nextPrice)
            );
        }
    }

    function _computeNextPrice(
            Witnet.DataResult memory result, 
            PriceData memory prevData,
            IWitPriceFeeds.UpdateConditions memory updateConditions
        )
        private pure 
        returns (Price memory)
    {
        uint64 _nextEmaPrice;
        uint64 _nextPrice = result.fetchUint();
        Witnet.Timestamp _nextTimestamp = result.timestamp;
        uint64 _prevPrice = prevData.price;
        int256 _deltaPrice;
        uint64 _deltaSecs;
        if (
            !prevData.timestamp.isZero()
                && _nextTimestamp.gt(prevData.timestamp)
        ) {
            // evalute delta price and eventual max deviation threshold condition,
            // as long as this is not the first price-feed update:
            _deltaPrice = int(uint(_nextPrice)) - int(uint(_prevPrice)) ;
            uint _absDeltaPrice = _deltaPrice > 0 ? uint(_deltaPrice) : uint(-_deltaPrice);
            require(
                _absDeltaPrice <= (2 ** 55) - 1, 
                IWitPythErrors.DeviantPrice()
            );
            _deltaSecs = Witnet.Timestamp.unwrap(result.timestamp) - Witnet.Timestamp.unwrap(prevData.timestamp);
            if (
                updateConditions.maxDeviation1000 > 0
                    &&  _computeDeviation1000(_prevPrice, _deltaPrice) > updateConditions.maxDeviation1000
            ) {
                // avoid updating price values and timestamp if too much deviation is detected,
                // but still update `deltaPrice` so calls to safe `get*Price*` variants
                // can revert with `DeviantPrice()`:
                _nextPrice = _prevPrice;
                _nextTimestamp = prevData.timestamp;
                _deltaSecs = 0;
            }
        }
        if (updateConditions.computeEma) {
            if (_deltaSecs > 0) {
                // todo: reaching this point, compute exponentially-moving average:
            
            } else {
                _nextEmaPrice = _nextPrice;
            }
        }
        return Price({
            data: PriceData({
                emaPrice: _nextEmaPrice, 
                price: _nextPrice,
                deltaPrice: int56(_deltaPrice),
                exponent: prevData.exponent,
                timestamp: _nextTimestamp
            }),
            track: result.drTxHash
        });
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

    function _footprintOf(IWitPriceFeeds.ID4 id4) private view returns (bytes4) {
        WitPriceFeedsDataLib.PriceFeed storage self = seekPriceFeed(id4);
        if (self.oracleSources == bytes32(0)) {
            return self.mapper != IWitPriceFeeds.Mappers.None ? (
                bytes4(keccak256(abi.encodePacked(
                    IWitPriceFeeds.ID4.unwrap(id4), 
                    self.mapperDeps
                )))
            ) : (
                bytes4(keccak256(abi.encodePacked(
                    IWitPriceFeeds.ID4.unwrap(id4), 
                    self.oracleAddress
                )))
            );

        } else {
            return bytes4(keccak256(abi.encodePacked(
                IWitPriceFeeds.ID4.unwrap(id4), 
                self.oracleSources
            )));
        }
    }

    function _intoID4(IWitPyth.ID id) private pure returns (IWitPriceFeeds.ID4) {
        return IWitPriceFeeds.ID4.wrap(bytes4(IWitPyth.ID.unwrap(id)));
    }

    function _intoWitPythID(IWitPriceFeeds.ID4 id4) private view returns (IWitPyth.ID) {
        return data().ids[data().records[id4].index];
    }

    function _intoWitPythPriceFeed(
            IWitPriceFeeds.ID priceId,
            Witnet.DataResult memory result,
            PriceData memory prevData,
            IWitPriceFeeds.UpdateConditions memory updateConditions
        )
        private pure
        returns (IWitPyth.PriceFeed memory)
    {
        Price memory _next = _computeNextPrice(result, prevData, updateConditions);
        uint64 _nextDeviation1000 = uint64(
            _next.data.deltaPrice >= 0 
                ? int64(_next.data.deltaPrice) 
                : int64(-_next.data.deltaPrice)
        );
        return IWitPyth.PriceFeed({
            id: priceId,
            price: IWitPyth.Price({
                price: _next.data.price,
                conf: _nextDeviation1000,
                expo: _next.data.exponent,
                publishTime: _next.data.timestamp,
                track: _next.track
            }),
            emaPrice: IWitPyth.Price({
                price: _next.data.emaPrice,
                conf: _nextDeviation1000,
                expo: _next.data.exponent,
                publishTime: _next.data.timestamp,
                track: _next.track
            })
        });
    }

    function _settlePriceFeedSymbol(string calldata symbol) private returns (IWitPriceFeeds.ID4 id4) {
        bytes32 _id = hash(symbol);
        id4 = IWitPriceFeeds.ID4.wrap(bytes4(_id));
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
            delete __record.lastWitUpdate;
            data().ids.push(IWitPyth.ID.wrap(_id));
        }
    }
}
