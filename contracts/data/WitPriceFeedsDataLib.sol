// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

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
    
    bytes32 private constant _WIT_FEEDS_DATA_SLOTHASH =
        /* keccak256("io.witnet.feeds.data") */
        0xe36ea87c48340f2c23c9e1c9f72f5c5165184e75683a4d2a19148e5964c1d1ff;

    struct Storage {
        IWitPriceFeeds.Id[] ids;
        mapping (IWitPriceFeeds.Id => PriceFeed) records;
        mapping (Witnet.RadonHash => IWitPriceFeeds.Id) reverseIds;
        mapping (IWitPriceFeeds.Id => IWitPriceFeeds.Id[]) reverseDeps;
        
        IWitPriceFeeds.WitParams requiredWitParams;
        IWitPriceFeeds.UpdateConditions defaultUpdateConditions;
        bytes32 _0;
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
        
        /// @dev As to store dependencies of this routed price feed.
        IWitPriceFeeds.Id[] solverDeps;

        /// @dev Hash of only accepted RadonRequest on the Wit/Oracle blockchain that can provide updates.
        Witnet.RadonHash radonHash;

        /// @dev Price-feed specific update conditions, if other's than default ones.
        IWitPriceFeeds.UpdateConditions updateConditions;

        /// @dev Last valid update data. 
        Price lastUpdate;
    }


    // ================================================================================================================
    // --- Public methods ---------------------------------------------------------------------------------------------

    function createPriceFeedSolver(
            bytes calldata initcode,
            bytes calldata params
        )
        public
        returns (IWitPriceFeedsMappingSolver)
    {
        address _solver = determinePriceFeedSolverAddress(initcode, params);
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

    function determinePriceFeedSolverAddress(
            bytes calldata initcode,
            bytes calldata params
        )
        public view
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

    function getPrice(IWitPriceFeeds.Id id, bool ema)
        public view 
        returns (IWitPyth.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id);
        Price memory _lastUpdate = __record.lastUpdate;
        if (!_lastUpdate.data.timestamp.isZero()) {
            uint24 _heartbeatSecs = coalesce(__record.updateConditions).heartbeatSecs;
            if (
                _heartbeatSecs == 0 
                    || block.timestamp < Witnet.Timestamp.unwrap(_lastUpdate.data.timestamp) + _heartbeatSecs 
            ) {
                return IWitPyth.Price({
                    price: ema ? _lastUpdate.data.emaPrice : _lastUpdate.data.price,
                    expo: _lastUpdate.data.exponent,
                    publishtime: _lastUpdate.data.timestamp,
                    track: _lastUpdate.track
                });
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

    function getPriceNotOlderThan(IWitPriceFeeds.Id id, uint64 age, bool ema)
        public view 
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

    function getPriceUnsafe(IWitPriceFeeds.Id id, bool ema)
        public view 
        returns (IWitPyth.Price memory)
    {
        PriceFeed storage __record = seekPriceFeed(id);
        Price memory _lastUpdate = __record.lastUpdate;
        if (!_lastUpdate.data.timestamp.isZero()) {
            return IWitPyth.Price({
                price: ema ? _lastUpdate.data.emaPrice : _lastUpdate.data.price,
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

    function getPricesUnsafe(IWitPriceFeeds.Id[] calldata ids, bool ema)
        public view
        returns (IWitPyth.Price[] memory _prices)
    {
        _prices = new IWitPyth.Price[](ids.length);
        for (uint _ix = 0; _ix < ids.length; _ix ++) {
            _prices[_ix] = getPriceUnsafe(ids[_ix], ema);
        }
    }

    function parsePriceFeedUpdates(
            IWitOracle witOracle,
            bytes[] calldata updates,
            IWitPyth.Id[] calldata ids,
            Witnet.Timestamp minTimestamp,
            Witnet.Timestamp maxTimestamp,
            bool checkUniqueness
        )
        public view
        returns (IWitPyth.PriceFeed[] memory _priceFeeds)
    {
        _priceFeeds = new IWitPyth.PriceFeed[](ids.length);
        unchecked {
            IWitPriceFeeds.WitParams memory _requiredWitParams = data().requiredWitParams;
            for (uint _ix = 0; _ix < updates.length; _ix ++) {
                // deserialize actual data push report and authenticity proof:
                (Witnet.DataPushReport memory _report, bytes memory _proof) = abi.decode(
                    updates[_ix], 
                    (Witnet.DataPushReport, bytes)
                );

                // check that governance target rules are met:
                require(
                    _report.witDrSLA.witCommitteeSize >= _requiredWitParams.witCommitteeSize
                        && _report.witDrSLA.witInclusionFees >= _requiredWitParams.witInclusionFees,
                    IWitPythErrors.InvalidGovernanceTarget()
                );

                // revert if any of the allegedly fresh update refers a radonHash 
                // that's not actually settled on any of the supported price-feeds:
                IWitPyth.Id _priceId = data().reverseIds[_report.witRadonHash];
                require(
                    IWitPyth.Id.unwrap(_priceId) != 0, 
                    IWitPythErrors.InvalidUpdateDataSource()
                );

                // revert if order of provided `updates` does not match the order of `ids`
                require(
                    IWitPyth.Id.unwrap(_priceId) == IWitPyth.Id.unwrap(ids[_ix]),
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
                        && (
                            !checkUniqueness ||
                            minTimestamp.gt(_prevData.timestamp)
                        )
                ) {
                    _priceFeeds[_ix] = _intoWitPythPriceFeed(_priceId, _data, _prevData);
                }
            }
            // revert in case there was at least one price with no actual update within given range:
            for (uint _ix = 0; _ix < _priceFeeds.length; _ix ++) {
                require(
                    IWitPyth.Id.unwrap(_priceFeeds[_ix].id) != bytes32(0), 
                    IWitPythErrors.PriceFeedNotFoundWithinRange()
                );
            }
        }
    }

    function updatePriceFeed(
            IWitOracle witOracle, 
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
        IWitPyth.Id _priceId = data().reverseIds[report.witRadonHash];
        require(
            IWitPyth.Id.unwrap(_priceId) != 0, 
            IWitPythErrors.InvalidUpdateDataSource()
        );

        PriceFeed storage __record = seekPriceFeed(_priceId);
        PriceData memory _lastUpdate = __record.lastUpdate.data;
        
        // consider updating price-feed's last update only if reported value is more recent:
        if (_result.timestamp.gt(_lastUpdate.timestamp)) {

            // revert if any of the allegedly fresh updates actually contains 
            // no integer value:
            require(
                _result.dataType == Witnet.RadonDataTypes.Integer
                    && _result.status == Witnet.ResultStatus.NoErrors,
                IWitPythErrors.InvalidUpdateData()
            );

            // compute next data point based on `_result` and `_lastUpdate`
            __record.lastUpdate = _computeNextPrice(_result, _lastUpdate);
        }
    }

    
    // ================================================================================================================
    // --- Price-feed admin methods -----------------------------------------------------------------------------------

    function removePriceFeed(IWitPyth.Id id, bool recursively) public returns (string[] memory) {
        // TODO
    }

    function settlePriceFeedMapping(
            IWitPyth.Id id, 
            IWitPriceFeedsMappingSolver solver, 
            string[] calldata deps,
            int8 exponent
        )
        public
    {
        // TODO
    }

    function settlePriceFeedRadonBytecode(
            IWitPyth.Id id,
            bytes calldata radonBytecode,
            int8 exponent,
            IWitOracleRadonRegistry registry
        )
        public
    {
        // TODO
    }

    function settlePriceFeedRadonHash(
            IWitPyth.Id id,
            Witnet.RadonHash radonHash,
            int8 exponent,
            IWitOracleRadonRegistry registry
        )
        public
    {
        // TODO
    }

    
    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function coalesce(IWitPriceFeeds.UpdateConditions storage self) 
        internal view 
        returns (IWitPriceFeeds.UpdateConditions memory)
    {
        return IWitPriceFeeds.UpdateConditions({
            deviation1000: self.deviation1000 == 0 ? data().defaultUpdateConditions.deviation1000 : self.deviation1000,
            heartbeatSecs: self.heartbeatSecs == 0 ? data().defaultUpdateConditions.heartbeatSecs : self.heartbeatSecs
        });
    }

    /// @notice Returns storage pointer to where Storage data is located. 
    function data() internal pure returns (Storage storage _ptr) {
        assembly {
            _ptr.slot := _WIT_FEEDS_DATA_SLOTHASH
        }
    }

    function seekPriceFeed(IWitPriceFeeds.Id id) internal view returns (PriceFeed storage) {
        return data().records[id];
    }


    // ================================================================================================================
    // --- Private methods --------------------------------------------------------------------------------------------

    function _completeInitCode(bytes calldata initcode, bytes calldata params)
        private pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            initcode,
            params
        );
    }

    function _computeNextPrice(Witnet.DataResult memory result, PriceData memory prevData)
        private pure 
        returns (Price memory)
    {
        // evalute delta price and eventual deviation threshold condition,
        // as long as this is not the first price-feed update:
        uint64 _nextPrice = result.fetchUint();
        uint64 _prevPrice = prevData.price;
        uint64 _nextEmaPrice = prevData.price;
        int256 _deltaPrice;
        uint64 _deltaSecs;
        if (!prevData.timestamp.isZero() && result.timestamp.gt(prevData.timestamp)) {
            _deltaPrice = int(uint(_nextPrice)) - int(uint(_prevPrice)) ;
            uint _absDeltaPrice = _deltaPrice > 0 ? uint(_deltaPrice) : uint(-_deltaPrice);
            require(
                _absDeltaPrice <= (2 ** 55) - 1, 
                IWitPythErrors.InvalidUpdateData()
            );
            _deltaSecs = Witnet.Timestamp.unwrap(result.timestamp) - Witnet.Timestamp.unwrap(prevData.timestamp);
        }
        if (_deltaSecs > 0) {
            // todo: reaching this point, compute expontially-moving average:
        }
        return Price({
            data: PriceData({
                emaPrice: _nextEmaPrice, 
                price: _nextPrice,
                deltaPrice: int56(_deltaPrice),
                exponent: prevData.exponent,
                timestamp: result.timestamp
            }),
            track: result.drTxHash
        });
    }

    function _intoWitPythPriceFeed(
            IWitPyth.Id priceId,
            Witnet.DataResult memory result,
            PriceData memory prevData
        )
        private pure
        returns (IWitPyth.PriceFeed memory)
    {
        Price memory _next = _computeNextPrice(result, prevData);
        return IWitPyth.PriceFeed({
            id: priceId,
            price: IWitPyth.Price({
                price: _next.data.price,
                expo: _next.data.exponent,
                publishtime: _next.data.timestamp,
                track: _next.track
            }),
            emaPrice: IWitPyth.Price({
                price: _next.data.emaPrice,
                expo: _next.data.exponent,
                publishtime: _next.data.timestamp,
                track: _next.track
            })
        });
    }

}
