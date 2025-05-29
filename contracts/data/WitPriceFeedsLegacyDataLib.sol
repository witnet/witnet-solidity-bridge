// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitOracle.sol";

import "../interfaces/legacy/IWitPriceFeedsLegacy.sol";
import "../interfaces/legacy/IWitPriceFeedsLegacyAdmin.sol";
import "../interfaces/legacy/IWitPriceFeedsLegacySolver.sol";
import "../libs/Slices.sol";

/// @title WitPriceFeedsLegacy data model.
/// @author The Witnet Foundation.
library WitPriceFeedsLegacyDataLib {

    using Slices for string;
    using Slices for Slices.Slice;

    using Witnet for Witnet.DataResult;
    using Witnet for Witnet.QueryId;
    using Witnet for Witnet.ResultStatus;
    
    bytes32 private constant _WIT_FEEDS_DATA_SLOTHASH =
        /* keccak256("io.witnet.feeds.data") */
        0xe36ea87c48340f2c23c9e1c9f72f5c5165184e75683a4d2a19148e5964c1d1ff;

    struct Storage {
        bytes32 reserved;
        bytes4[] ids;
        mapping (bytes4 => Record) records;
    }

    struct Record {
        string  caption;
        uint8   decimals;
        uint256 index;
        uint256 lastValidQueryId;
        uint256 latestUpdateQueryId;
        bytes32 radHash;
        address solver;         // logic contract address for reducing values on routed feeds.
        int256  solverReductor; // as to reduce resulting number of decimals on routed feeds.
        bytes32 solverDepsFlag; // as to store ids of up to 8 depending feeds.
    }

    
    // ================================================================================================
    // --- Internal functions -------------------------------------------------------------------------
    
    /// @notice Returns array of feed ids from which given feed's value depends.
    /// @dev Returns empty array on either unsupported or not-routed feeds.
    /// @dev The maximum number of dependencies is hard-limited to 8, as to limit number
    /// @dev of SSTORE operations (`__storage().records[feedId].solverDepsFlag`), 
    /// @dev no matter the actual number of depending feeds involved.
    function depsOf(bytes4 feedId) internal view returns (bytes4[] memory _deps) {
        bytes32 _solverDepsFlag = data().records[feedId].solverDepsFlag;
        _deps = new bytes4[](8);
        uint _len;
        for (_len = 0; _len < 8; _len ++) {
            _deps[_len] = bytes4(_solverDepsFlag);
            if (_deps[_len] == 0) {
                break;
            } else {
                _solverDepsFlag <<= 32;
            }
        }
        assembly {
            // reset length to actual number of dependencies:
            mstore(_deps, _len)
        }
    }

    /// @notice Returns storage pointer to where Storage data is located. 
    function data()
      internal pure
      returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WIT_FEEDS_DATA_SLOTHASH
        }
    }

    function hash(string memory caption) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(caption)));
    }

    function lastValidQueryId(IWitOracleQueriable witOracle, bytes4 feedId)
        internal view 
        returns (uint256 _queryId)
    {
        _queryId = seekRecord(feedId).latestUpdateQueryId;
        if (
            _queryId == 0
                || witOracle.getQueryResultStatus(_queryId) != Witnet.ResultStatus.NoErrors
        ) {
            _queryId = seekRecord(feedId).lastValidQueryId;
        }
    }

    function latestUpdateQueryResultStatus(IWitOracleQueriable witOracle, bytes4 feedId)
        internal view
        returns (Witnet.ResultStatus)
    {
        uint256 _queryId = seekRecord(feedId).latestUpdateQueryId;
        if (_queryId != 0) {
            return witOracle.getQueryResultStatus(_queryId);
        } else {
            return Witnet.ResultStatus.NoErrors;
        }
    }

    /// @notice Returns storage pointer to where Record for given feedId is located.
    function seekRecord(bytes4 feedId) internal view returns (Record storage) {
        return data().records[feedId];
    }

    function seekPriceSolver(bytes4 feedId) internal view returns (
            address _solverAddress,
            string[] memory _solverDeps
        )
    {
        _solverAddress = seekRecord(feedId).solver;
        bytes4[] memory _deps = depsOf(feedId);
        _solverDeps = new string[](_deps.length);
        for (uint _ix = 0; _ix < _deps.length; _ix ++) {
            _solverDeps[_ix] = seekRecord(_deps[_ix]).caption;
        }
    }


    // ================================================================================================
    // --- Public functions ---------------------------------------------------------------------------

    function deleteFeed(string calldata caption) public {
        bytes4 feedId = hash(caption);
        bytes4[] storage __ids = data().ids;
        Record storage __record = seekRecord(feedId);
        uint _index = __record.index;
        require(_index != 0, "unknown feed");
        bytes4 _lastFeedId = __ids[__ids.length - 1];
        __ids[_index - 1] = _lastFeedId;
        __ids.pop();
        seekRecord(_lastFeedId).index = _index;
        delete data().records[feedId];
        emit IWitPriceFeedsLegacyAdmin.WitFeedDeleted(caption, feedId);
    }

    function deleteFeeds() public {
        bytes4[] storage __ids = data().ids;
        for (uint _ix = __ids.length; _ix > 0; _ix --) {
            bytes4 _feedId = __ids[_ix - 1];
            string memory _caption = data().records[_feedId].caption;
            delete data().records[_feedId]; __ids.pop();
            emit IWitPriceFeedsLegacyAdmin.WitFeedDeleted(_caption, _feedId);
        }
    }

    function latestPrice(
            IWitOracleQueriable witOracle,
            bytes4 feedId
        ) 
        public view 
        returns (IWitPriceFeedsLegacySolver.Price memory)
    {
        uint256 _queryId = lastValidQueryId(witOracle, feedId);
        if (_queryId != 0) {
            Witnet.DataResult memory _lastValidResult = witOracle.getQueryResult(_queryId);
            return IWitPriceFeedsLegacySolver.Price({
                value: _lastValidResult.fetchUint(),
                timestamp: _lastValidResult.timestamp,
                drTxHash: _lastValidResult.drTxHash,
                latestStatus: _intoLatestUpdateStatus(latestUpdateQueryResultStatus(witOracle, feedId))
            });
        
        } else {
            address _solver = seekRecord(feedId).solver;
            if (_solver != address(0)) {
                // solhint-disable-next-line avoid-low-level-calls
                (bool _success, bytes memory _result) = address(this).staticcall(abi.encodeWithSelector(
                    IWitPriceFeedsLegacySolver.solve.selector,
                    feedId
                ));
                if (!_success) {
                    assembly {
                        _result := add(_result, 4)
                    }
                    revert(string(abi.decode(_result, (string))));
                } else {
                    return abi.decode(_result, (IWitPriceFeedsLegacySolver.Price));
                }
            } else {
                return IWitPriceFeedsLegacySolver.Price({
                    value: 0,
                    timestamp: Witnet.Timestamp.wrap(0),
                    drTxHash: Witnet.TransactionHash.wrap(0),
                    latestStatus: _intoLatestUpdateStatus(latestUpdateQueryResultStatus(witOracle, feedId))
                });
            }
        }
    }

    function requestUpdate(
            IWitOracleQueriable witOracle, 
            bytes4 feedId, 
            Witnet.QuerySLA memory querySLA,
            uint256 evmUpdateRequestFee
        )
        public
        returns (
            uint256 _latestQueryId,
            uint256 _evmUsedFunds
        )
    {
        Record storage __feed = seekRecord(feedId);
        _latestQueryId = __feed.latestUpdateQueryId;
        
        Witnet.ResultStatus _latestStatus = latestUpdateQueryResultStatus(witOracle, feedId);   
        if (_latestStatus.keepWaiting()) {
            uint72 _evmUpdateRequestCurrentFee = Witnet.QueryEvmReward.unwrap(
                witOracle.getQueryEvmReward(_latestQueryId)
            );
            if (evmUpdateRequestFee > _evmUpdateRequestCurrentFee) {
                // latest update is still pending, so just increase the reward
                // accordingly to current tx gasprice:
                _evmUsedFunds = (evmUpdateRequestFee - _evmUpdateRequestCurrentFee);
                witOracle.upgradeQueryEvmReward{
                    value: _evmUsedFunds
                }(
                    _latestQueryId
                );
            
            } else {
                _evmUsedFunds = 0;
            }
        
        } else {
            // Check if latest update ended successfully:
            if (_latestStatus == Witnet.ResultStatus.NoErrors) {
                // If so, remove previous last valid query from the WRB:
                if (__feed.lastValidQueryId != 0) {
                    evmUpdateRequestFee += Witnet.QueryEvmReward.unwrap(
                        witOracle.deleteQuery(__feed.lastValidQueryId)
                    );                    
                }
                __feed.lastValidQueryId = _latestQueryId;
            } else {
                // Otherwise, try to delete latest query, as it was faulty
                // and we are about to post a new update request:
                try witOracle.deleteQuery(_latestQueryId) returns (Witnet.QueryEvmReward _unsedReward) {
                    evmUpdateRequestFee += Witnet.QueryEvmReward.unwrap(_unsedReward);
                
                } catch {}
            }
            // Post update request to the WRB:
            _evmUsedFunds = evmUpdateRequestFee;
            _latestQueryId = witOracle.queryData{
                value: _evmUsedFunds
            }(
                Witnet.RadonHash.wrap(__feed.radHash),
                querySLA
            );
            // Update latest query id:
            __feed.latestUpdateQueryId = _latestQueryId;
        }
    }

    function settleFeedRequest(
            string calldata caption,
            bytes32 radHash
        )
        public
    {
        bytes4 feedId = hash(caption);
        Record storage __record = seekRecord(feedId);
        if (__record.index == 0) {
            // settle new feed:
            __record.caption = caption;
            __record.decimals = validateCaption(caption);
            __record.index = data().ids.length + 1;
            __record.radHash = radHash;
            data().ids.push(feedId);
        } else if (__record.radHash != radHash) {
            // update radHash on existing feed:
            __record.radHash = radHash;
            __record.solver = address(0);
        }
        emit IWitPriceFeedsLegacyAdmin.WitFeedSettled(caption, feedId, radHash);
    }

    function settleFeedSolver(
            string calldata caption, 
            address solver, 
            string[] calldata deps
        )
        public
    {
        bytes4 feedId = hash(caption);        
        Record storage __record = seekRecord(feedId);
        if (__record.index == 0) {
            // settle new feed:
            __record.caption = caption;
            __record.decimals = validateCaption(caption);
            __record.index = data().ids.length + 1;
            __record.solver = solver;
            data().ids.push(feedId);
            
        } else if (__record.solver != solver) {
            // update radHash on existing feed:
            __record.radHash = 0;
            __record.solver = solver;
        }
        // validate solver first-level dependencies
        {
            // solhint-disable-next-line avoid-low-level-calls
            (bool _success, bytes memory _reason) = solver.delegatecall(abi.encodeWithSelector(
                IWitPriceFeedsLegacySolver.validate.selector,
                feedId,
                deps
            ));
            if (!_success) {
                assembly {
                    _reason := add(_reason, 4)
                }
                revert(string(abi.encodePacked(
                    "solver validation failed: ",
                    string(abi.decode(_reason,(string)))
                )));
            }
        }
        // smoke-test the solver 
        {   
            // solhint-disable-next-line avoid-low-level-calls
            (bool _success, bytes memory _reason) = address(this).staticcall(abi.encodeWithSelector(
                IWitPriceFeedsLegacySolver.solve.selector,
                feedId
            ));
            if (!_success) {
                assembly {
                    _reason := add(_reason, 4)
                }
                revert(string(abi.encodePacked(
                    "smoke-test failed: ",
                    string(abi.decode(_reason,(string)))
                )));
            }
        }
        emit IWitPriceFeedsLegacyAdmin.WitFeedSolverSettled(caption, feedId, solver);
    }

    function supportedFeeds() public view returns (
            bytes4[] memory _ids,
            string[] memory _captions,
            bytes32[] memory _solvers
        )
    {
        _ids = data().ids;
        _captions = new string[](_ids.length);
        _solvers = new bytes32[](_ids.length);
        for (uint _ix = 0; _ix < _ids.length; _ix ++) {
            Record storage __record = seekRecord(_ids[_ix]);
            _captions[_ix] = __record.caption;
            _solvers[_ix] = (
                address(__record.solver) == address(0) 
                    ? __record.radHash 
                    : bytes32(bytes20(__record.solver))
            );
        }
    }

    // --- IWitPriceFeedsLegacySolver public functions -------------------------------------------------------------

    function deployPriceSolver(
            bytes calldata initcode,
            bytes calldata constructorParams
        )
        external
        returns (address _solver)
    {
        _solver = determinePriceSolverAddress(initcode, constructorParams);
        if (_solver.code.length == 0) {
            bytes memory _bytecode = _completeInitCode(initcode, constructorParams);
            address _createdContract;
            assembly {
                _createdContract := create2(
                    0, 
                    add(_bytecode, 0x20),
                    mload(_bytecode), 
                    0
                )
            }
            // assert(_solver == _createdContract); // fails on TEN chains
            _solver = _createdContract;
            require(
                IWitPriceFeedsLegacySolver(_solver).specs() == type(IWitPriceFeedsLegacySolver).interfaceId,
                "uncompliant solver implementation"
            );
        }
    }

    function determinePriceSolverAddress(
            bytes calldata initcode,
            bytes calldata constructorParams
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
                    keccak256(_completeInitCode(initcode, constructorParams))
                )
            )))
        );
    }

    function validateCaption(string calldata caption) public pure returns (uint8) {
        Slices.Slice memory _caption = caption.toSlice();
        Slices.Slice memory _delim = string("-").toSlice();
        string[] memory _parts = new string[](_caption.count(_delim) + 1);
        for (uint _ix = 0; _ix < _parts.length; _ix ++) {
            _parts[_ix] = _caption.split(_delim).toString();
        }
        (uint _decimals, bool _success) = Witnet.tryUint(_parts[_parts.length - 1]);
        require(_success, "bad decimals");
        return uint8(_decimals);
    }

    
    // ================================================================================================
    // --- Private functions --------------------------------------------------------------------------

    function _completeInitCode(bytes calldata initcode, bytes calldata constructorParams)
        private pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            initcode,
            constructorParams
        );
    }

    function _intoLatestUpdateStatus(Witnet.ResultStatus _resultStatus)
        private pure 
        returns (IWitPriceFeedsLegacySolver.LatestUpdateStatus)
    {
        return (_resultStatus.keepWaiting() 
            ? IWitPriceFeedsLegacySolver.LatestUpdateStatus.Awaiting
            : (_resultStatus.hasErrors()
                ? IWitPriceFeedsLegacySolver.LatestUpdateStatus.Error
                : IWitPriceFeedsLegacySolver.LatestUpdateStatus.Ready
            )
        );
    }

}
