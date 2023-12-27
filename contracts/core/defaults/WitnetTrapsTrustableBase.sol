// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetUpgradableBase.sol";
import "../../WitnetBytecodes.sol";
import "../../WitnetTraps.sol";

import "../../data/WitnetTrapsData.sol";
import "../../interfaces/IWitnetRequestBoardAdminACLs.sol";

/// @title Witnet Traps Board "trustable" base implementation contract.
/// @notice Contract where to subscribe PUSH data traps, and where PUSH data can get eventually reported
/// @notice as long as data gets externally signed by pre-authorized (trustable) authorities.
/// @author The Witnet Foundation
abstract contract WitnetTrapsTrustableBase
    is 
        WitnetUpgradableBase,
        WitnetTraps,
        WitnetTrapsData,
        IWitnetRequestBoardAdminACLs
{
    using Witnet for Witnet.RadonDataTypes;
    using Witnet for Witnet.Result;
 
    bytes4 public immutable override specs = type(IWitnetTraps).interfaceId;
    WitnetBytecodes immutable public override registry;
  
    constructor(
            WitnetBytecodes _registry,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.traps"
        )
    {
        registry = _registry;
    }

    /// @dev Provide backwards compatibility for dapps bound to versions <= 0.6.1
    /// @dev (i.e. calling methods in IWitnetRequestBoard)
    /// @dev (Until 'function ... abi(...)' modifier is allegedly supported in solc versions >= 0.9.1)
    /* solhint-disable payable-fallback */
    /* solhint-disable no-complex-fallback */
    fallback() override external { 
        revert(string(abi.encodePacked(
            "WitnetTrapsTrustableBase: not implemented: 0x",
            Witnet.toHexString(uint8(bytes1(msg.sig))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 8))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 16))),
            Witnet.toHexString(uint8(bytes1(msg.sig << 24)))
        )));
    }

    
    // ================================================================================================================
    // --- Yet to be implemented virtual methods ----------------------------------------------------------------------

    function _blockNumber() virtual internal view returns (uint64);
    function _blockTimestamp() virtual internal view returns (uint64);
    function _hashTrapReport(TrapReport calldata) virtual internal pure returns (bytes16);
    function estimateBaseFee(uint256 gasPrice, uint16 maxResultSize) virtual public view returns (uint256);

    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData)
        public
        override
    {
        address _owner = owner();
        if (_owner == address(0)) {
            // get owner (and reporters) from _initData
            bytes memory _reportersRaw;
            (_owner, _reportersRaw) = abi.decode(_initData, (address, bytes));
            _transferOwnership(_owner);
            __setReporters(abi.decode(_reportersRaw, (address[])));
        } else {
            // only owner can initialize:
            require(
                msg.sender == _owner,
                "WitnetTrapsTrustableBase: not the owner"
            );
            // get reporters from _initData
            __setReporters(abi.decode(_initData, (address[])));
        }

        if (__storage().base != address(0)) {
            // current implementation cannot be initialized more than once:
            require(
                __storage().base != base(),
                "WitnetTrapsTrustableBase: already upgraded"
            );
        }        
        __storage().base = base();

        require(
            address(registry).code.length > 0,
            "WitnetTrapsTrustableBase: inexistent registry"
        );
        require(
            registry.specs() == type(IWitnetBytecodes).interfaceId, 
            "WitnetTrapsTrustableBase: uncompliant registry"
        );

        emit Upgraded(_owner, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = owner();
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }


    // ================================================================================================================
    // --- Full implementation of 'IWitnetRequestBoardAdminACLs' ------------------------------------------------------

    /// Tells whether given address is included in the active reporters control list.
    /// @param _reporter The address to be checked.
    function isReporter(address _reporter) public view override returns (bool) {
        return __storage().isReporter[_reporter];
    }

    /// Adds given addresses to the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersSet` event. 
    /// @param _reporters List of addresses to be added to the active reporters control list.
    function setReporters(address[] memory _reporters)
        public
        override
        onlyOwner
    {
        __setReporters(_reporters);
    }

    /// Removes given addresses from the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersUnset` event. 
    /// @param _exReporters List of addresses to be added to the active reporters control list.
    function unsetReporters(address[] memory _exReporters)
        public
        override
        onlyOwner
    {
        for (uint ix = 0; ix < _exReporters.length; ix ++) {
            address _reporter = _exReporters[ix];
            __storage().isReporter[_reporter] = false;
        }
        emit ReportersUnset(_exReporters);
    }


    // ================================================================================================================
    // --- 'IWitnetTraps' ---------------------------------------------------------------------------------------------

    receive() virtual override external payable { 
        emit Funded(msg.sender, __fund(msg.sender));
    }

    function balanceOf(address _feeder)
        virtual override
        external view
        returns (uint256)
    {
        return __storage().balances[_feeder];
    }

    function fund(address _feeder)
        virtual override 
        public payable
        returns (uint256 _newBalance)
    {
        _newBalance = __fund(_feeder);
        emit Funded(_feeder, _newBalance);
    }

    function getActiveTrapInfo(bytes32 _trapId)
        virtual override
        external view
        returns (TrapInfo memory)
    {
        TrapStorage storage __trap = __seekTrap(_trapId);
        if (__trap.feeder == address(0)) {
            revert NoTrap();
        } else {
            return _toTrapInfo(__trap);
        }
    }

    function getActiveTrapsCount()
        virtual override
        external view
        returns (uint64)
    {
        return uint64(__storage().trapIds.length);
    }

    function getActiveTrapsRange(uint64 _offset, uint64 _length)
        virtual override
        external view 
        returns (bytes32[] memory _ids, TrapInfo[] memory _traps)
    {
        uint64 _totalTraps = uint64(__storage().trapIds.length);
        require(
            _offset < _totalTraps, 
            "WitnetTraps: offset out of range"
        );
        if (_offset + _length > _totalTraps) {
            _length = _totalTraps - _offset;
        }
        _ids = new bytes32[](_length);
        _traps = new TrapInfo[](_length);
        for (uint64 _ix = 0; _ix < _length; _ix ++) {
            _ids[_ix] = __storage().trapIds[_offset + _ix];
            _traps[_ix] = _toTrapInfo(__seekTrap(_ids[_ix]));
        }
    }

    function getDataFeedLastUpdate(address _feeder, bytes4 _dataFeedId)
        virtual override
        external view
        returns (DataPoint memory _data)
    {
        _data = getDataFeedLastUpdateUnsafe(_feeder, _dataFeedId);
        TrapStorage storage __trap = __seekTrap(_feeder, _dataFeedId);
        if (
            __trap.sla.heartbeatSecs > 0
                && _blockTimestamp() > _data.drTimestamp + __trap.sla.heartbeatSecs
        ) {
            revert ExpiredValue();
        }
    }

    function getDataFeedLastUpdateUnsafe(address _feeder, bytes4 _dataFeedId)
        virtual override
        public view
        returns (DataPoint memory _data)
    {
        TrapStorage storage __trap = __seekTrap(_feeder, _dataFeedId);
        uint _finalityBlock = _extractDataPointFinalityBlock(__trap.dataPtr);
        if (__trap.feeder == address(0)) {
            revert NoTrap();
        } else if (_finalityBlock == 0) {
            revert NoValue();
        }
        if (_blockNumber() < _finalityBlock) {
            _data = _extractDataPoint(__trap.prevDataPtr);
        } else {
            _data = _extractDataPoint(__trap.dataPtr);
        }
    }

    function getDataFeedTrapSLA(address _feeder, bytes4 _dataFeedId)
        virtual override
        external view 
        trapIsOwned(_feeder, _dataFeedId)
        returns (IWitnetTraps.SLA memory)
    {
        return __seekTrap(_feeder, _dataFeedId).sla;
    }

    function trapDataFeed(
            bytes4 _dataFeedId, 
            IWitnetTraps.SLA calldata _trapSLA
        )
        virtual override
        external payable
        returns (uint256 _newBalance)
    {
        if (msg.value > 0) {
            _newBalance = fund(msg.sender);
        }
        bytes32 _trapId = _hashTrap(msg.sender, _dataFeedId);
        TrapStorage storage __trap = __seekTrap(_trapId);
        if (__trap.feeder == address(0)) {
            // push new trapId value to storage array:
            __storage().trapIds.push(_trapId);
            __trap.index = uint64(__storage().trapIds.length) - 1;
            // initialize data storage pointers:
            __trap.dataPtr = keccak256(abi.encode(
                _WITNET_TRAPS_DATA_SLOTHASH,
                _trapId,
                uint(0)
            ));
            __trap.prevDataPtr = keccak256(abi.encode(
                _WITNET_TRAPS_DATA_SLOTHASH,
                _trapId,
                uint(1)
            ));
        } else {
            // if RAD Hash changes, makes sure that the data type prevails
            if (_trapSLA.radHash != __trap.sla.radHash) {
                require(
                    registry.lookupRadonRequestResultDataType(_trapSLA.radHash)
                        == registry.lookupRadonRequestResultDataType(__trap.sla.radHash),
                    "WitnetTraps: data types mistmatch"
                );
            }
        }
        
        // validate SLA parameters: 
        _validateTrapSLA(_trapSLA);
        
        // sava/update SLA into storage:
        __trap.sla = _trapSLA;
        
        // emit event:
        emit Trap(_trapId, msg.sender, _trapSLA);
    }

    function untrapDataFeed(bytes4 _dataFeedId)
        virtual override
        external
        trapIsOwned(msg.sender, _dataFeedId)
        returns (DataPoint memory _lastData)
    {
        bytes32 _trapId = _hashTrap(msg.sender, _dataFeedId);
        TrapStorage storage __trap = __seekTrap(_trapId);
        
        // remove trapId from storage array:
        __storage().trapIds[__trap.index] = __storage().trapIds[__storage().trapIds.length - 1];
        __storage().trapIds.pop();
        
        // extact last known data point:
        _lastData = _extractDataPoint(__trap.dataPtr);

        // delete Trap from storage (but not previous values, if any):
        delete __storage().traps[_trapId];
        
        // emit event:
        IWitnetTraps.SLA memory _emptySLA;
        emit Trap(_trapId, msg.sender, _emptySLA);
    }

    function reportDataFeeds(TrapReport[] calldata _reports)
        virtual override
        external
        nonReentrant
        onlyReporters
        returns (TrapReportStatus[] memory _status_, uint256 _totalEvmReward)
    {
        _status_ = new TrapReportStatus[](_reports.length);
        address _feeder;
        uint256 _feederBalance;
        for (uint _ix = 0; _ix < _reports.length; _ix ++) {
            TrapStorage storage __trap = __seekTrap(_reports[_ix].trapId);
            TrapReportStatus _status = TrapReportStatus.Unknown;
            if (__trap.feeder != address(0)) {
                if (_feeder == address(0)) {
                    _feeder = __trap.feeder;
                    _feederBalance = __storage().balances[_feeder];
                } else if (_feeder != __trap.feeder) {
                    revert("WitnetTraps: disjoint reports");
                }
                _status = __reportDataFeed(_reports[_ix], __trap);
                if (_status == IWitnetTraps.TrapReportStatus.Reported) {
                    uint256 _evmReward = _calcEvmReward(
                        tx.gasprice,
                        uint16(_reports[_ix].drTallyCborBytes.length),
                        __trap.sla.reportFee10000
                    );
                    if (_totalEvmReward + _evmReward > _feederBalance) {
                        _status = TrapReportStatus.InsufficientBalance;
                    } else {
                        _totalEvmReward += _evmReward;
                        __saveDataPoint(_reports[_ix], __trap);
                    }
                }
            }
            _status_[_ix] = _status;
        }
        if (_feeder != msg.sender) {
            __storage().balances[_feeder] -= _totalEvmReward;
            __storage().balances[msg.sender] += _totalEvmReward;
            emit Rewarded(_feeder, msg.sender, _totalEvmReward);
        }
    }

    function reportDataFeeds(
            TrapReport[] calldata _reports, 
            bytes[] calldata _signatures
        )
        virtual override
        external
        nonReentrant
        returns (TrapReportStatus[] memory _status_)
    {
        _status_ = new TrapReportStatus[](_reports.length);
        for (uint _ix = 0; _ix < _reports.length; _ix ++) {
            TrapStorage storage __trap = __seekTrap(_reports[_ix].trapId);
            TrapReportStatus _status = TrapReportStatus.Unknown;
            if (__trap.feeder != address(0)) {
                _status = __reportDataFeed(_reports[_ix], __trap);
                if (_status == IWitnetTraps.TrapReportStatus.Reported) {
                    bytes32 _reportHash = _hashTrapReport(_reports[_ix]);
                    if (!__storage().isReporter[Witnet.recoverAddr(_reportHash, _signatures[_ix])]) {
                        _status = IWitnetTraps.TrapReportStatus.InvalidSignature;
                    } else {
                        __saveDataPoint(_reports[_ix], __trap);
                    }
                }
            }
            _status_[_ix] = _status;
        }
    }    

    function withdraw()
        virtual override 
        external 
        returns (uint256 _withdrawn)
    {
        _withdrawn = __storage().balances[msg.sender];
        __storage().balances[msg.sender] = 0;
        emit Withdrawn(
            msg.sender, 
            __safeTransferTo(
                payable(msg.sender), 
                _withdrawn
            )
        );
    }


    // ================================================================================================================
    // --- Virtual and internal functions -----------------------------------------------------------------------------

    function _calcEvmReward(uint256 _gasPrice, uint16 _maxResultSize, uint16 _reportFee10000)
        virtual internal view
        returns (uint256)
    {
        return (
            estimateBaseFee(_gasPrice, _maxResultSize)
                * (
                    10000
                        + _reportFee10000
                )
        ) / 10000;
    }

    function _calcResultDeviation10000(
            Witnet.Result memory _result,
            TrapStorage storage __trap
        )
        internal view
        returns (uint64)
    {
        if (__trap.sla.dataType == Witnet.RadonDataTypes.Integer) {
            int64 _current = int64(Witnet.asInt(
                Witnet.resultFromCborBytes(
                    _extractDataPoint(__trap.dataPtr).drTallyCborBytes
                )
            ));
            int64 _diff = int64(Witnet.asInt(_result)) - _current;
            if (_diff < 0) _diff *= -1;
            return uint64(_diff * 10000) / uint64(_current);
        } else if (
            keccak256(_result.value.buffer.data)
                != keccak256(_extractDataPoint(__trap.dataPtr).drTallyCborBytes)
        ) {
            return 1;
        } else {
            return 0;
        }
    }

    function _toTrapInfo(TrapStorage storage __trap)
        virtual internal view 
        returns (IWitnetTraps.TrapInfo memory)
    {
        return TrapInfo({
            feedId: __trap.feedId,
            feeder: __trap.feeder,
            balance: __storage().balances[__trap.feeder],
            bytecode: registry.bytecodeOf(__trap.sla.radHash),
            dataType: __trap.sla.dataType.toString(),
            lastData: (
                _blockNumber() >= _extractDataPointFinalityBlock(__trap.dataPtr)
                    ? _extractDataPoint(__trap.dataPtr)
                    : _extractDataPoint(__trap.prevDataPtr)
            ),
            trapSLA: __trap.sla
        });
    }

    function _validateTrapSLA(IWitnetTraps.SLA calldata sla) virtual internal view {
        require(sla.radHash != 0, "WitnetTraps: no RAD hash?");
        require(sla.maxGasPrice > 0, "WitnetTraps: no max gas price?");
        require(sla.maxResultSize > 0, "WitnetTraps: no result size?");
        require(sla.minWitnesses > 0, "WitnetTraps: no witnesses?");
        require(
            (sla.heartbeatSecs == 0 && sla.cooldownSecs == 0)
                || sla.heartbeatSecs >= sla.cooldownSecs,
            "WitnetTraps: invalid heartbeat"
        );
        Witnet.RadonDataTypes _radDataType = registry.lookupRadonRequestResultDataType(sla.radHash);
        require(sla.dataType == _radDataType, "WitnetTraps: RAD data type mismatch");
        if (
            _radDataType != Witnet.RadonDataTypes.Integer
                && sla.deviationThreshold10000 > 1
        ) {
            revert("WitnetTraps: invalid deviation threshold");
        }
    }

    function __fund(address _feeder)
        virtual internal
        returns (uint256 _newBalance)
    {
        _newBalance = __storage().balances[_feeder] + msg.value;
        __storage().balances[_feeder] = _newBalance;
    }

    function __reportDataFeed(
            TrapReport calldata _report,
            TrapStorage storage __trap
        )
        virtual internal
        returns (TrapReportStatus _status)
    {
        // DataPoint storage __lastData = _extractDataPoint(__trap.dataPtr);
        (uint64 _lastFinalityBlock, uint64 _lastDrTimestamp) = _extractDataPointFinalityBlockAndTimestamp(__trap.dataPtr);
        Witnet.Result memory _result = Witnet.resultFromCborBytes(_report.drTallyCborBytes);
        IWitnetTraps.SLA memory _sla = __trap.sla;

        int32 _elapsedSecs = int32(int64(_report.drTimestamp) - int64(_lastDrTimestamp));
        if (
            !_result.success
                || _result.dataType() != _sla.dataType
                || (
                    _sla.maxResultSize != 0
                        && _report.drTallyCborBytes.length > _sla.maxResultSize
                )
        ) {
            _status = TrapReportStatus.InvalidResult;
        } else if (_blockNumber() < _lastFinalityBlock) {
            _status = TrapReportStatus.PreviousValueNotFinalized;
        } else if (_report.drRadHash != _sla.radHash) {
            _status = TrapReportStatus.InvalidRadHash;
        } else if (
            _lastDrTimestamp != 0 && _elapsedSecs > 0
                || (
                    _sla.maxTimestamp > 0
                        && _blockTimestamp() > _sla.maxTimestamp
                )
        ) {
            _status = TrapReportStatus.InvalidTimestamp;
        } else if (_report.drWitnesses < _sla.minWitnesses) {
            _status = TrapReportStatus.InsufficientWitnesses;                    
        } else if (_sla.cooldownSecs > 0 && _elapsedSecs < int32(_sla.cooldownSecs)) {
            _status = TrapReportStatus.InsufficientCooldown;
        } else if (
            _sla.deviationThreshold10000 > 0 
                && _calcResultDeviation10000(_result, __trap) < _sla.deviationThreshold10000
                && (
                    _sla.heartbeatSecs == 0
                        || _elapsedSecs < int32(_sla.heartbeatSecs)
                )
        ) {
            _status = TrapReportStatus.InsufficientDeviation;
        } else if (
            _sla.maxGasPrice > 0
                && tx.gasprice > _sla.maxGasPrice
        ) {
            _status = TrapReportStatus.ExcessiveGasPrice;
        } else {
            _status = TrapReportStatus.Reported;
        }
    }
        
    /// Transfers ETHs to given address.
    /// @param _to Recipient address.
    /// @param _quantity Amount of ETHs to transfer.
    function __safeTransferTo(address payable _to, uint256 _quantity)
        virtual
        internal
        returns (uint256)
    {
        _to.transfer(_quantity);
        return _quantity;
    }

    function __saveDataPoint(TrapReport calldata _report, TrapStorage storage __trap)
        virtual internal
    {
        bytes32 _dataPtr = __trap.prevDataPtr;
        __trap.prevDataPtr = __trap.dataPtr;
        __trap.dataPtr = _dataPtr;
        DataPointPacked storage __datapoint = __seekDataPointPacked(_dataPtr);
        __datapoint.drTallyCborBytes = _report.drTallyCborBytes;
        __datapoint.packed = (
            bytes32(_hashTrapReport(_report) << 128)
                | bytes32(uint(_report.drTimestamp) << 64)
                | bytes32(uint(_blockNumber()))
        );
    }

    function __setReporters(address[] memory _reporters)
        virtual internal
    {
        for (uint ix = 0; ix < _reporters.length; ix ++) {
            address _reporter = _reporters[ix];
            __storage().isReporter[_reporter] = true;
        }
        emit ReportersSet(_reporters);
    }

}