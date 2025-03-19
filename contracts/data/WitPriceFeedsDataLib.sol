// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

import "../interfaces/IWitOracle.sol";
import "../interfaces/IWitOracleRadonRegistry.sol";
import "../interfaces/IWitPriceFeeds.sol";
import "../interfaces/IWitPriceFeedsAdmin.sol";
import "../interfaces/IWitPriceFeedsMappingSolver.sol";

import "../libs/Slices.sol";
import "../mockups/WitPriceFeedsChainlinkAggregator.sol";

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
        /// @dev /Human-readable symbol for this price feed.
        string symbol;
        
        /// @dev (Required for removing price-feed settlements from storage)
        uint32 index;

        /// @dev Base-10 exponent to compute actual price.
        int8 exponent;
        
        /// @dev (As to reduce resulting number of decimals on routed feeds)
        int56 solverReducingExponent;
        
        /// @dev Logic-contract address for reducing values on routed feeds.
        IWitPriceFeedsMappingSolver solver;
        
        /// @dev As to store up to 8 dependencies of this routed price feed.
        bytes32 solverDepsFlag;

        /// @dev Hash of only accepted RadonRequest on the Wit/Oracle blockchain that can provide updates.
        Witnet.RadonHash radonHash;

        /// @dev Price-feed specific update conditions, if other's than default ones.
        IWitPriceFeeds.UpdateConditions updateConditions;

        /// @dev Last valid update data. 
        Price lastUpdate;
    }

    struct WitParams {
        uint16 minWitCommitteeSize;
        uint16 maxWitCommitteeSize;
    }


    // ================================================================================================================
    // --- Public methods ---------------------------------------------------------------------------------------------

    function fetchChainlinkAggregator(IWitPriceFeeds.ID4 id4) public returns (IWitPythChainlinkAggregator) {
        bytes memory _initcode = type(WitPriceFeedsChainlinkAggregator).creationCode;
        bytes memory _params = abi.encodePacked(
            address(this),
            id4
        );
        address _contract = _determineCreate2Address(_initcode, _params);
        if (_contract.code.length == 0) {
            bytes memory _bytecode = _completeInitCode(_initcode, _params);
            assembly {
                _contract := create2(
                    0,
                    add(_bytecode, 0x20),
                    mload(_bytecode),
                    0
                )
            }
        }
        return IWitPythChainlinkAggregator(_contract);
    }

    function createPriceFeedSolver(
            bytes memory initcode,
            bytes memory params
        )
        public
        returns (IWitPriceFeedsMappingSolver)
    {
        address _solver = _determineCreate2Address(initcode, params);
        if (_solver.code.length == 0) {
            bytes memory _bytecode = _completeInitCode(initcode, params);
            assembly {
                _solver := create2(
                    0,
                    add(_bytecode, 0x20),
                    mload(_bytecode),
                    0
                )
            }
            require(
                IWitPriceFeedsMappingSolver(_solver).specs() == type(IWitPriceFeedsMappingSolver).interfaceId,
                "uncompliant initcode"
            );
        }
        return IWitPriceFeedsMappingSolver(_solver);
    }

    function determinePriceFeedSolverAddress(bytes calldata initcode, bytes calldata params) public view returns (address) {
        return _determineCreate2Address(initcode, params);
    }

    function getPrice(
            IWitPriceFeeds.ID4 id, 
            bool ema
        )
        internal view 
        returns (IWitPyth.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id);
        Price memory _lastUpdate = __record.lastUpdate;
        
        if (!_lastUpdate.data.timestamp.isZero()) {
            IWitPriceFeeds.UpdateConditions memory _updateConditions = coalesce(__record.updateConditions);
        
            if (_updateConditions.maxDeviation1000 > 0) {
                require(
                    _computeDeviation1000(_lastUpdate.data.price, _lastUpdate.data.deltaPrice)
                        <= _updateConditions.maxDeviation1000,
                    IWitPythErrors.DeviantPrice()
                );
            }
            
            if (
                _updateConditions.heartbeatSecs == 0 
                    || block.timestamp < Witnet.Timestamp.unwrap(_lastUpdate.data.timestamp) + _updateConditions.heartbeatSecs
            ) {
                if (!ema || _updateConditions.computeEma) {
                    return IWitPyth.Price({
                        price: ema ? _lastUpdate.data.emaPrice : _lastUpdate.data.price,
                        conf: uint64(
                            _lastUpdate.data.deltaPrice >= 0 
                                ? int64(_lastUpdate.data.deltaPrice) 
                                : int64(-_lastUpdate.data.deltaPrice)
                        ),
                        expo: _lastUpdate.data.exponent,
                        publishtime: _lastUpdate.data.timestamp,
                        track: _lastUpdate.track
                    });
                } else {
                    revert IWitPythErrors.InvalidGovernanceTarget();
                }
            } else {
                revert IWitPythErrors.StalePrice();
            }
        
        } else if (!__record.radonHash.isZero()) {
            // TODO: get routed price
            revert("todo");
        
        } else {
            revert IWitPythErrors.PriceFeedNotFound();
        }
    }

    function getPriceNotOlderThan(IWitPriceFeeds.ID4 id, bool ema, uint24 age)
        internal view 
        returns (IWitPyth.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id);
        Price memory _lastUpdate = __record.lastUpdate;
        if (!_lastUpdate.data.timestamp.isZero()) {
            if (
                block.timestamp < Witnet.Timestamp.unwrap(_lastUpdate.data.timestamp) + age
            ) {
                return IWitPyth.Price({
                    price: ema ? _lastUpdate.data.emaPrice : _lastUpdate.data.price,
                    conf: uint64(
                        _lastUpdate.data.deltaPrice >= 0 
                            ? int64(_lastUpdate.data.deltaPrice) 
                            : int64(-_lastUpdate.data.deltaPrice)
                    ),
                    expo: _lastUpdate.data.exponent,
                    publishtime: _lastUpdate.data.timestamp,
                    track: _lastUpdate.track
                });
            } else {
                revert IWitPythErrors.StalePrice();
            }
        
        } else if (!__record.radonHash.isZero()) {
            // TODO
            revert("todo");

        } else {
            revert IWitPythErrors.PriceFeedNotFound();
        }
    }

    function getPriceUnsafe(IWitPriceFeeds.ID4 id, bool ema)
        internal view 
        returns (IWitPyth.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id);
        Price memory _lastUpdate = __record.lastUpdate;
        if (!_lastUpdate.data.timestamp.isZero()) {
            return IWitPyth.Price({
                price: ema ? _lastUpdate.data.emaPrice : _lastUpdate.data.price,
                conf: uint64(
                    _lastUpdate.data.deltaPrice >= 0 
                        ? int64(_lastUpdate.data.deltaPrice) 
                        : int64(-_lastUpdate.data.deltaPrice)
                ),
                expo: _lastUpdate.data.exponent,
                publishtime: _lastUpdate.data.timestamp,
                track: _lastUpdate.track
            });
        
        } else if (!__record.radonHash.isZero()) {
            // TODO
            revert("todo");

        } else {
            revert IWitPythErrors.PriceFeedNotFound();
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
                PriceData memory _prevData = __record.lastUpdate.data;
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
        // roll-up wit/oracle proof and deserialize price update data,
        // as long as the update report is proven to be authentic:
        Witnet.DataResult memory _result = witOracle.pushDataReport(report, proof);

        // revert if any of the allegedly fresh update refers a radonHash 
        // that's not actually settled on any of the supported price-feeds:
        IWitPriceFeeds.ID4 _priceId = data().reverseIds[report.witRadonHash];
        require(
            IWitPriceFeeds.ID4.unwrap(_priceId) != 0, 
            IWitPythErrors.InvalidUpdateDataSource()
        );

        PriceFeed storage __record = seekPriceFeed(_priceId);
        PriceData memory _lastUpdate = __record.lastUpdate.data;
        IWitPriceFeeds.UpdateConditions memory _updateConditions = coalesce(__record.updateConditions, defaultUpdateConditions);
        
        // consider updating price-feed's last update only if reported value is more recent:
        if (
            Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + _updateConditions.cooldownSecs
                < Witnet.Timestamp.unwrap(_result.timestamp)
        ) {
            // revert if any of the allegedly fresh updates actually contains 
            // no integer value:
            require(
                _result.dataType == Witnet.RadonDataTypes.Integer
                    && _result.status == Witnet.ResultStatus.NoErrors,
                IWitPythErrors.InvalidUpdateData()
            );

            // compute next data point based on `_result` and `_lastUpdate`
            __record.lastUpdate = _computeNextPrice(_result, _lastUpdate, _updateConditions);
        }
    }

    
    // ================================================================================================================
    // --- Price-feed admin methods -----------------------------------------------------------------------------------

    function removePriceFeed(IWitPriceFeeds.ID4 id4, bool recursively) public {
        IWitPriceFeeds.ID4[] memory _reverseDeps = data().reverseDeps[id4];
        require(
            recursively
                || _reverseDeps.length == 0,
            "WitPriceFeedsDataLib: cannot remove if mapped by others"  
        );
        for (uint _ix; _ix < _reverseDeps.length; ++ _ix) {
            removePriceFeed(_reverseDeps[_ix], recursively);
        }
        PriceFeed storage self = seekPriceFeed(id4);
        if (self.radonHash.isZero()) {
            delete self.solverReducingExponent;
            delete self.solver;
            delete self.solverDepsFlag;
        } else {
            self.radonHash = Witnet.RadonHash.wrap(0);
        }
        delete data().reverseDeps[id4];
    }

    function settlePriceFeedExponent(
            PriceFeed storage self,
            IWitPriceFeeds.ID4 id4,
            int8 exponent
        ) public
    {
        require(
            data().reverseDeps[id4].length == 0 
                || exponent == self.exponent,
            "WitPriceFeedsDataLib: cannot change exponent if mapped by others"
        );
        if (exponent != self.exponent) {
            self.exponent = exponent;
            self.lastUpdate.data.exponent = exponent;
        }
    }

    function settlePriceFeedFootprint() public returns (bytes4 _footprint) {
        _footprint = _computePriceFeedsFootprint();
        data().footprint = _footprint;
    }

    function settlePriceFeedMapping(
            string calldata,
            IWitPriceFeedsMappingSolver,
            string[] calldata,
            int8
        )
        public
        returns (bytes4)
    {
        // TODO ...
        // IWitPriceFeeds.ID4 id4 = settlePriceFeedSymbol(symbol);
        
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
        IWitPriceFeeds.ID4 id4 = settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        if (address(registry) != address(0)) {
            _radonHash = registry.hashOf(radonBytecode);
        } else {
            revert("WitPriceFeedsDataLib: WitOracleRadonRegistry is required");
        }
        __record.radonHash = _radonHash;
        __record.solver = IWitPriceFeedsMappingSolver(address(0));
        settlePriceFeedExponent(__record, id4, exponent);
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
        IWitPriceFeeds.ID4 id4 = settlePriceFeedSymbol(symbol);
        PriceFeed storage __record = seekPriceFeed(id4);
        if (address(registry) != address(0)) {
            require(
                registry.exists(radonHash),
                "WitPriceFeedsDataLib: unknown radon hash"
            );
        } else {
            __record.radonHash = radonHash;
        }
        __record.solver = IWitPriceFeedsMappingSolver(address(0));
        settlePriceFeedExponent(__record, id4, exponent);
        return settlePriceFeedFootprint();
    }

    function settlePriceFeedSymbol(string calldata symbol) public returns (IWitPriceFeeds.ID4 id4) {
        bytes32 _id = hash(symbol);
        id4 = IWitPriceFeeds.ID4.wrap(bytes4(_id));
        PriceFeed storage __record = seekPriceFeed(id4);
        if (
            keccak256(abi.encode(symbol))
                != keccak256(abi.encode(__record.symbol))
        ) {
            require(
                data().reverseDeps[id4].length == 0,
                "WitPriceFeedsDataLib: cannot refactor exisitng symbol if mapped by others"
            );
            __record.symbol = symbol;
            __record.index = uint32(data().ids.length);
            delete __record.lastUpdate;
            data().ids.push(IWitPyth.ID.wrap(_id));
        }
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
        bytes32 _solverDepsFlag = data().records[self].solverDepsFlag;
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

    function hash(string calldata symbol) internal pure returns (bytes32) {
        return keccak256(abi.encode(symbol));
    }

    function seekPriceFeed(IWitPriceFeeds.ID4 id4) internal view returns (PriceFeed storage) {
        return data().records[id4];
    }


    // ================================================================================================================
    // --- Private methods --------------------------------------------------------------------------------------------

    function _completeInitCode(bytes memory initcode, bytes memory params)
        private pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            initcode,
            params
        );
    }

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

    function _determineCreate2Address(
            bytes memory initcode,
            bytes memory params
        )
        private view
        returns (address)
    {
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

    function _footprintOf(IWitPriceFeeds.ID4 id4) private view returns (bytes4) {
        WitPriceFeedsDataLib.PriceFeed storage self = seekPriceFeed(id4);
        if (self.radonHash.isZero()) {
            return bytes4(keccak256(abi.encodePacked(
                IWitPriceFeeds.ID4.unwrap(id4), 
                self.solverDepsFlag
            )));
        } else {
            return bytes4(keccak256(abi.encodePacked(
                IWitPriceFeeds.ID4.unwrap(id4), 
                self.radonHash
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
                publishtime: _next.data.timestamp,
                track: _next.track
            }),
            emaPrice: IWitPyth.Price({
                price: _next.data.emaPrice,
                conf: _nextDeviation1000,
                expo: _next.data.exponent,
                publishtime: _next.data.timestamp,
                track: _next.track
            })
        });
    }

}
