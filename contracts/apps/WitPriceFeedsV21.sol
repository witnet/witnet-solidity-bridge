// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../WitPriceFeeds.sol";
import "../data/WitPriceFeedsDataLib.sol";
import "../interfaces/IWitPriceFeedsAdmin.sol";
import "../mockups/UsingWitOracle.sol";
import "../patterns/Ownable2Step.sol";

/// @title WitPriceFeeds: Price Feeds powered by the Wit/Oracle and potentially usable by Chainlink and Pyth clients.
/// @author Guillermo Díaz <guillermo@witnet.io>

contract WitPriceFeedsV21
    is
        Ownable2Step,
        WitPriceFeeds,
        IWitPriceFeedsAdmin
{
    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.RadonHash;
    using Witnet for Witnet.Timestamp;

    using WitPriceFeedsDataLib for UpdateConditions;

    function class() virtual override public pure returns (string memory) {
        return type(WitPriceFeedsV21).name;
    }

    constructor(
            address _witOracle, 
            address _witOracleRadonRegistry,
            address _operator,
            WitParams memory _witParams
        )
        Ownable(_operator != address(0) ? _operator : msg.sender)
    {
        __storage().requiredWitParams = _witParams;
        _require(
            _witOracle != address(0), 
            "inexistent oracle"
        );
        _require(
            IWitAppliance(_witOracle).specs() == (
                type(IWitAppliance).interfaceId
                    ^ type(IWitOracle).interfaceId
                    ^ type(IWitOracleQueriable).interfaceId                
            ) || IWitAppliance(_witOracle).specs() == (
                type(IWitAppliance).interfaceId
                    ^ type(IWitOracle).interfaceId
            ),
            "uncompliant wit/oracle"
        );
        _require(
            _witOracleRadonRegistry == address(0)
                || IWitAppliance(_witOracleRadonRegistry).specs() == (
                    type(IWitAppliance).interfaceId
                        ^ type(IWitOracleRadonRegistry).interfaceId
                ), 
            "uncompliant WitOracleRadonRegistry"
        );
        witOracle = IWitOracle(_witOracle);
        witOracleRadonRegistry = IWitOracleRadonRegistry(_witOracleRadonRegistry);
    }

    receive() virtual external payable {
        _revert("no transfers accepted");
    }

    fallback() virtual external payable { 
        _revert(string(abi.encodePacked(
            "not implemented: 0x",
            Witnet.toHexString(uint8(bytes1(msg.sig))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 8))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 16))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 24)))
        )));
    }


    /// ===============================================================================================================
    /// --- IERC2362 --------------------------------------------------------------------------------------------------

    function valueFor(bytes32 _id)
        override
        external view
        returns (int256 _value, uint256 _timestamp, uint256 _status)
    {
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(Id.wrap(_id));
        UpdateConditions memory _updateConditions = __record.updateConditions.coalesce();
        WitPriceFeedsDataLib.PriceData memory _lastUpdate = __record.lastUpdate.data;        
        _value = int(uint(_lastUpdate.price));
        _timestamp = uint(Witnet.Timestamp.unwrap(_lastUpdate.timestamp));
        _status = (
            _timestamp == 0 
                ? 404
                : (
                    block.timestamp > Witnet.Timestamp.unwrap(_lastUpdate.timestamp) + _updateConditions.heartbeatSecs
                        ? 400 
                        : 200
            )
        );
    }


    /// ===============================================================================================================
    /// --- IWitPriceFeeds --------------------------------------------------------------------------------------------

    function createChainlinkAggregator(Id _id) external override returns (IWitPythChainlinkAggregator) {
        // try WitPriceFeedsDataLib
        //     .createChainlinkAggregator(_id)
        
        // returns (IWitPythChainlinkAggregator _aggregator) {
        //     return _aggregator;
        // }
        // catch Error(string memory _reason) { 
        //     _revert(_reason);    
        // } 
        // catch (bytes memory) { 
        //     _revertUnhandled(); 
        // }
    }
    
    function determineChainlinkAggregatorAddress(Id _id) external override view returns (address) {
        // return WitPriceFeedsDataLib.determineChainlinkAggregatorAddress(_id);
    }

    /// Returns a unique hash determined by the combination of data sources being used by 
    /// supported non-routed price feeds, and dependencies of all supported routed 
    /// price feeds. The footprint changes if any price feed is modified, added, removed 
    /// or if the dependency tree of any routed price feed is altered.
    function footprint()external override view returns (bytes4 _footprint) {
        if (__storage().ids.length > 0) {
            _footprint = _footprintOf(__storage().ids[0]);
            for (uint _ix = 1; _ix < __storage().ids.length; _ix ++) {
                _footprint ^= _footprintOf(__storage().ids[_ix]);
            }
        }
    }
    
    function hash(string calldata _symbol) public pure returns (Id) {
        return Id.wrap(keccak256(abi.encode(_symbol)));
    }
    
    function lookupPriceFeed(Id _id) override public view returns (Info memory) {
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(_id);
        return Info({
            id: _id,
            exponent: __record.exponent,
            sources: __record.radonHash,
            symbol: __record.symbol
        });
    }
    
    function lookupPriceFeedSolver(Id _id)
        external override view returns (IWitPriceFeedsMappingSolver, Id[] memory)
    {
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(_id);
        return (
            __record.solver,
            __record.solverDeps
        );
    }

    function lookupPriceFeedUpdateConditions(Id _id) external override view returns (UpdateConditions memory) {
        return __seekPriceFeed(_id).updateConditions.coalesce();
        // return UpdateConditions({
        //     heartbeatSecs: (
        //         __updateConditions.heartbeatSecs == 0
        //             ? __storage().defaultUpdateConditions.heartbeatSecs
        //             : __updateConditions.heartbeatSecs
        //     ),
        //     deviation1000: (
        //         __updateConditions.deviation1000 == 0
        //             ? __storage().defaultUpdateConditions.deviation1000
        //             : __updateConditions.deviation1000
        //     )
        // });
    }

    function lookupSymbol(Id _id) external override view returns (string memory _symbol) {
        return __seekPriceFeed(_id).symbol;
    }

    function supportedPriceFeeds() external override view returns (Info[] memory _infos) {
        Id[] memory _ids = __storage().ids;
        _infos = new Info[](_ids.length);
        for (uint _ix = 0; _ix < _ids.length; _ix ++) {
            _infos[_ix] = lookupPriceFeed(_ids[_ix]);
        }
    }

    function supportsPriceFeed(string calldata _symbol) external override view returns (bool) {
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(hash(_symbol));
        return (
            !__record.radonHash.isZero()
                || address(__record.solver) != address(0)
        );
    }

    function witOracleRequiredParams() external override view returns (WitParams memory) {
        return __storage().requiredWitParams;
    }


    /// ===============================================================================================================
    /// --- IWitPriceFeedsAdmin ---------------------------------------------------------------------------------------

    function createPriceFeedSolver(bytes calldata initcode, bytes calldata params)
        external override
        onlyOwner
        returns (IWitPriceFeedsMappingSolver)
    {
        try WitPriceFeedsDataLib.createPriceFeedSolver(
            initcode, 
            params
        
        ) returns (IWitPriceFeedsMappingSolver _solver) {
            return _solver;
        
        } catch Error(string memory _reason) { 
            _revert(_reason); 
            
        } catch (bytes memory) { 
            _revertUnhandled(); 
        }
    }

    function determinePriceFeedSolverAddress(bytes calldata initcode, bytes calldata params)
        external view override 
        returns (address)
    {
        return WitPriceFeedsDataLib.determinePriceFeedSolverAddress(initcode, params);
    }

    function removePriceFeed(string calldata _symbol, bool _recursively) 
        external override
        onlyOwner
        returns (string[] memory)
    {
        return WitPriceFeedsDataLib.removePriceFeed(hash(_symbol), _recursively);
    }

    function settleDefaultUpdateConditions(IWitPriceFeeds.UpdateConditions calldata _conditions)
        external override
        onlyOwner
    {
        __storage().defaultUpdateConditions = _conditions;
    }

    function settleRequiredWitParams(WitParams calldata _params)
        external override
        onlyOwner
    {
        __storage().requiredWitParams = _params;
    }

    function settlePriceFeedMapping(
            string calldata _symbol, 
            IWitPriceFeedsMappingSolver _solver, 
            string[] calldata _deps,
            int8 _exponent
        ) 
        external override
        onlyOwner
    {
        _require(address(_solver) != address(0), "no solver address");
        try WitPriceFeedsDataLib.settlePriceFeedMapping(hash(_symbol), _solver, _deps, _exponent) {}
        catch Error(string memory _reason) { _revert(_reason); }
        catch (bytes memory) { _revertUnhandled(); }
    }

    function settlePriceFeedRadonBytecode(
            string calldata _symbol, 
            bytes calldata _radonBytecode,
            int8 _exponent
        )
        external override 
        onlyOwner
    {
        WitPriceFeedsDataLib.settlePriceFeedRadonBytecode(
            hash(_symbol),
            _radonBytecode,
            _exponent,
            witOracleRadonRegistry
        );
    }

    function settlePriceFeedRadonHash(
            string calldata _symbol, 
            Witnet.RadonHash _radonHash,
            int8 _exponent
        )
        external override 
        onlyOwner
    {
        WitPriceFeedsDataLib.settlePriceFeedRadonHash(
            hash(_symbol),
            _radonHash,
            _exponent,
            witOracleRadonRegistry
        );
    }

    function settlePriceFeedUpdateConditions(
            string calldata _symbol, 
            IWitPriceFeeds.UpdateConditions calldata _conditions
        )
        external override
        onlyOwner
    {
        __seekPriceFeed(hash(_symbol)).updateConditions = _conditions;
    }


    /// ===============================================================================================================
    /// --- IWitPyth --------------------------------------------------------------------------------------------------

    /// @notice Returns the exponentially-weighted moving average price.
    /// @dev Reverts if the EMA price is not available, or if the price feeds is settled with a heartbeat
    /// and the price was not recently updated.
    /// @param _id The Price Feed ID of which to fetch the EMA price.
    function getEmaPrice(Id _id)
        external view override 
        returns (Price memory)
    {
        return WitPriceFeedsDataLib.getPrice(_id, true);
        
    }

    /// @notice Returns the exponentially-weighted moving average price that is no older than `_age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    function getEmaPriceNotOlderThan(Id _id, uint64 _age)
        external view override
        returns (Price memory)
    {
        return WitPriceFeedsDataLib.getPriceNotOlderThan(_id, _age, true);
    }

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    function getEmaPriceUnsafe(Id _id)
        external view override 
        returns (Price memory) 
    {
        return WitPriceFeedsDataLib.getPriceUnsafe(_id, true);
    }

    /// @notice Returns the latest known exponentially-weight average price for all required price feeds 
    /// without any sanity checks. This function is unsafe as the returned price updates may be arbitrarily 
    /// far in the past.
    /// 
    /// Users of this function should check the `timestamp` of each price feed to ensure that the returned values 
    /// are sufficiently recent for their application. If you need safe access to fresh data, please consider
    /// using calling to either `getEmaPrice` or `getEmaPriceNoOlderThan` for every individual price feed.
    function getEmaPricesUnsafe(Id[] calldata _ids)
        external view override
        returns (Price[] memory)
    {
        return WitPriceFeedsDataLib.getPricesUnsafe(_ids, true);
    }

    /// @notice Returns the price of given price feed.
    /// @dev Reverts if the price has not been updated within the last `heartbeatSecs`. 
    /// @param _id The Price Feed ID of which to fetch the price.
    function getPrice(Id _id)
        external view override
        returns (Price memory)
    {
        return WitPriceFeedsDataLib.getPrice(_id, false);
    }

    /// @notice Returns the price that is no older than `_age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. 
    /// Reverts if the price wasn't updated sufficiently
    /// recently.
    function getPriceNotOlderThan(Id _id, uint64 _age)
        external view override 
        returns (Price memory)
    {
        return WitPriceFeedsDataLib.getPriceNotOlderThan(_id, _age, false);
    }

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    /// 
    /// Users of this function should check the `timestamp` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    function getPriceUnsafe(Id _id)
        external view override
        returns (Price memory)
    {
        return WitPriceFeedsDataLib.getPriceUnsafe(_id, false);
    }

    /// @notice Returns the latest known update for all required price feeds without any sanity checks.
    /// This function is unsafe as the returned price updates may be arbitrarily far in the past.
    /// 
    /// Users of this function should check the `timestamp` of each price feed to ensure that the returned values 
    /// are sufficiently recent for their application. If you need safe access to fresh data, please consider
    /// using calling to either `getPrice` or `getPriceNoOlderThan` for every individual price feed.
    function getPricesUnsafe(Id[] calldata _ids)
        external view override
        returns (Price[] memory _prices)
    {
        return WitPriceFeedsDataLib.getPricesUnsafe(_ids, false);
    }
    

    /// @notice Legacy-compliant to get the required fee to update an array of price updates, which would be
    /// always 0 if relying from the Wit/Oracle framework.
    function getUpdateFee(bytes calldata) external override pure returns (uint256) {
        return 0;
    }

    /// @notice Parse `updates` and return price feeds of the given `ids` if they reported
    /// timestamps are within specified `minTimestamp` and `maxTimestamp`. Unlike `updatePriceFeeds`, 
    /// calling this function will NOT update the on-chain price. 
    ///
    /// Use this function if you just want to use reported updates as long as they refer
    /// a timestamp within the specified range, and not necessarily most recent updates in storage.  
    /// Otherwise, consider using `updatePriceFeeds` followed by any of `get*Price*` methods.
    ///
    /// If you need to make sure to get the earliest update after `minTimestamp` (ie. the one on-chain 
    /// or the one being parsed), consider using `parsePriceFeedUpdatesUnique` instead.
    /// 
    /// @dev Reverts if there is no update for any of the given `ids` within the given time range.
    /// @param updates Array of price update reports.
    /// @param ids Array of price ids.
    /// @param minTimestamp minimum acceptable publishTime for the given `ids`.
    /// @param maxTimestamp maximum acceptable publishTime for the given `ids`.
    function parsePriceFeedUpdates(
            bytes[] calldata updates, 
            Id[] calldata ids, 
            uint64 minTimestamp,
            uint64 maxTimestamp
        ) 
        external view override 
        returns (PriceFeed[] memory)
    {
        require(
            updates.length == ids.length, 
            IWitPythErrors.InvalidArgument()
        );
        return WitPriceFeedsDataLib.parsePriceFeedUpdates(
            witOracle,
            updates, 
            ids, 
            Witnet.Timestamp.wrap(minTimestamp), 
            Witnet.Timestamp.wrap(maxTimestamp), 
            false
        );
    }

    /// @notice Similar to `parsePriceFeedUpdates` but ensures the returned prices correspond to
    /// the earliest update after `minTimestamp`. That is to say, if `prevTs < minTs <= ts <= maxTs`, 
    /// where `prevTs` is the timestamp of latest on-chain timestamp for each referred price-feed.
    /// This will guarantee no updates exist for the given `priceIds` earlier than the returned 
    /// updates and still in the given time range. 
    
    /// Use this function is you just want to use reported updates for a fixed time window and 
    /// not necessarily the most recent update on-chain. Otherwise, consider using
    /// `updatePriceFeeds` followed by any of the  `get*PriceNoOlderThan` variants.
    /// 
    /// @dev Reverts if there is no update for any of the given `ids` within the given time range and 
    /// uniqueness condition.
    /// @param updates Array of price update reports.
    /// @param ids Array of price ids.
    /// @param minTimestamp minimum acceptable publishTime for the given `ids`.
    /// @param maxTimestamp maximum acceptable publishTime for the given `ids`.
    /// @return priceFeeds Array of the Prices corresponding to the given `ids` (with the same order).
    function parsePriceFeedUpdatesUnique(
            bytes[] calldata updates, 
            Id[] calldata ids, 
            uint64 minTimestamp,
            uint64 maxTimestamp
        )
        external view override 
        returns (PriceFeed[] memory) 
    {
        require(
            updates.length == ids.length, 
            IWitPythErrors.InvalidArgument()
        );
        return WitPriceFeedsDataLib.parsePriceFeedUpdates(
            witOracle,
            updates, 
            ids, 
            Witnet.Timestamp.wrap(minTimestamp), 
            Witnet.Timestamp.wrap(maxTimestamp), 
            true
        );
    }

    /// @notice Update price feeds with given update reports. Prices will be updated if 
    /// they are more recent than the current stored prices. The call will succeed even if 
    /// updates are not more recent.
    /// 
    /// @dev Reverts if any of the update reports is invalid.
    /// @param updates Array of price update reports.
     function updatePriceFeeds(bytes[] calldata updates)
        public override
    {
        IWitPriceFeeds.WitParams memory _requiredWitParams = __storage().requiredWitParams;
        for (uint _ix = 0; _ix < updates.length;) {
            
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

            WitPriceFeedsDataLib.updatePriceFeed(witOracle, _report, _proof);

            unchecked {
                _ix ++;
            }
        }
    }

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. 
    /// A price update is necessary if the current on-chain publishTime is older than the given timestamp. 
    /// It relies solely on the given `timestamps` for the price feeds and does not read the actual price update 
    /// publish time within `updates`.
    ///
    /// `ids` and `timestamps` are two arrays with the same size that correspond to sender's known timestamps
    /// of each Price Feed when calling this method. If all of price feeds within `ids` have updated and have
    /// a newer or equal timestamp than the given timestamp, it will reject the transaction to save gas.
    /// Otherwise, it calls `updatePriceFeeds` method to update the prices.
    ///
    /// @dev Reverts also if any of the price update data is valid.
    /// @param updates Array of price update data.
    /// @param ids Array of price ids.
    /// @param timestamps Array of timestamps: `timestamps[i]` corresponds to known `timestamp` of `ids[i]`
    function updatePriceFeedsIfNecessary(
            bytes[] calldata updates, 
            Id[] calldata ids, 
            Witnet.Timestamp[] calldata timestamps
        ) 
        external override 
    {        
        require(
            updates.length == ids.length
                && updates.length == timestamps.length,
            IWitPythErrors.InvalidArgument()
        );
        for (uint _ix = 0; _ix < ids.length;) {
            if (timestamps[_ix].gt(__seekPriceFeed(ids[_ix]).lastUpdate.data.timestamp)) {
                return updatePriceFeeds(updates);
            }
            unchecked {
                _ix ++;
            }
        }
        revert IWitPythErrors.NoFreshUpdate();
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _footprintOf(Id id) virtual internal view returns (bytes4) {
        WitPriceFeedsDataLib.PriceFeed storage __record = __seekPriceFeed(id);
        if (__record.radonHash.isZero()) {
            return bytes4(keccak256(abi.encodePacked(
                Id.unwrap(id), 
                __record.solverDeps
            )));
        } else {
            return bytes4(keccak256(abi.encodePacked(
                Id.unwrap(id), 
                __record.radonHash
            )));
        }
    }

    function _revertUnhandled() internal view {
        _revert("unhandled revert");
    }

    function __seekPriceFeed(Id _id) internal view returns (WitPriceFeedsDataLib.PriceFeed storage) {
        return WitPriceFeedsDataLib.seekPriceFeed(_id);
    }

    function __storage() internal pure returns (WitPriceFeedsDataLib.Storage storage) {
        return WitPriceFeedsDataLib.data();
    }

}
