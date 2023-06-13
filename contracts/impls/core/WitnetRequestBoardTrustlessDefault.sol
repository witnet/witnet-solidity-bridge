// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetUpgradableBase.sol";
import "../../WitnetRequestBoardV2.sol";
import "../../data/WitnetRequestBoardV2Data.sol";
import "../../patterns/Escrowable.sol";

import "../../libs/WitnetErrorsLib.sol";

/// @title Witnet Request Board "trustless" default implementation contract.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustlessDefault
    is 
        Escrowable,
        WitnetRequestBoardV2,
        WitnetRequestBoardV2Data,
        WitnetUpgradableBase
{
    using WitnetV2 for WitnetV2.QueryReport;
    
    bytes4 immutable public override DDR_QUERY_TAG;
    uint256 immutable internal _DDR_REPORT_QUERY_GAS_BASE;

    /// Asserts the given query is currently in some specific status.
    modifier queryInStatus(
            bytes32 queryHash,
            WitnetV2.QueryStatus queryStatus
        )
    {
        require(
            checkQueryStatus(queryHash) == queryStatus,
            _queryNotInStatusRevertMessage(queryStatus)
        );
        _;
    }

    modifier stakes(bytes32 queryHash) {
        __stake(
            msg.sender,
            __query_(queryHash).weiStake
        );
        _;
    }

    constructor(
            WitnetBlocks _blocks,
            WitnetRequestFactory _factory,
            uint256 _reportQueryGasBase,
            bool _upgradable,
            bytes32 _versionTag
        )
        Escrowable(IERC20(address(0)))
        WitnetRequestBoardV2(_blocks, _factory)
        WitnetUpgradableBase(
            _upgradable, 
            _versionTag,
            "io.witnet.proxiable.board"
        )
    {
        DDR_QUERY_TAG = bytes4(keccak256(abi.encodePacked(
            "evm:",
            Witnet.toString(block.chainid),
            ":",
            Witnet.toHexString(address(_blocks.board()))
        )));
        _DDR_REPORT_QUERY_GAS_BASE = _reportQueryGasBase;
    }

    function DDR_REPORT_QUERY_GAS_BASE()
        virtual override
        public view
        returns (uint256)
    {
        return _DDR_REPORT_QUERY_GAS_BASE;
    }

    function DDR_REPORT_QUERY_MIN_STAKE_WEI()
        virtual override
        public view
        returns (uint256)
    {
        return DDR_REPORT_QUERY_MIN_STAKE_WEI(_getGasPrice());
    }

    function DDR_REPORT_QUERY_MIN_STAKE_WEI(uint256 evmGasPrice)
        virtual override
        public view
        returns (uint256)
    {
        // 50% over given gas price
        return (blocks.ROLLUP_MAX_GAS() * evmGasPrice * 15) / 10;
    }


    // ================================================================================================================
    // --- Overrides 'Escrowable' -------------------------------------------------------------------------------------

    receive() external payable virtual override {
        __receive(msg.sender, msg.value);
    }

    function atStakeBy(address tenant)
        public view
        virtual override
        returns (uint256)
    {
        return __storage().escrows[tenant].atStake;
    }
    
    function balanceOf(address tenant)
        public view
        virtual override
        returns (uint256)
    {
        return __storage().escrows[tenant].balance;
    }

    function withdraw()
        external
        virtual override
        nonReentrant
        returns (uint256 _withdrawn)
    {
        _withdrawn = balanceOf(msg.sender);
        __storage().escrows[msg.sender].balance = 0;
        __safeTransferTo(payable(msg.sender), _withdrawn);
    }

    function __receive(address from, uint256 value)
        virtual override
        internal
    {
        __storage().escrows[from].balance += value;
        emit Received(from, value);
    }

    function __stake(address from, uint256 value)
        virtual override
        internal
    {
        Escrow storage __escrow = __storage().escrows[from];
        require(
            __escrow.balance >= value,
            "WitnetRequestBoardTrustlessDefault: insufficient balance"
        );
        __escrow.balance -= value;
        __escrow.atStake += value;
        emit Staked(from, value);
    }

    function __slash(address from, address to, uint256 value)
        virtual override
        internal
    {
        Escrow storage __escrow_from = __storage().escrows[from];
        Escrow storage __escrow_to = __storage().escrows[to];
        require(
            __escrow_from.atStake >= value,
            "WitnetRequestBoardTrustlessDefault: insufficient stake"
        );
        __escrow_from.atStake -= value;
        __escrow_to.balance += value;
        emit Slashed(from, to, value);
    }

    function __unstake(address from, uint256 value)
        virtual override
        internal
    {
        Escrow storage __escrow = __storage().escrows[from];
        require(
            __escrow.atStake >= value,
            "WitnetRequestBoardTrustlessDefault: insufficient stake"
        );
        __escrow.atStake -= value;
        __escrow.balance += value;
        emit Unstaked(from, value);
    }

    
    // ================================================================================================================
    // --- Overrides 'Payable' ----------------------------------------------------------------------------------------

    /// Gets current transaction price.
    function _getGasPrice()
        internal view
        virtual override
        returns (uint256)
    {
        return tx.gasprice;
    }

    /// Gets current payment value.
    function _getMsgValue()
        internal view
        virtual override
        returns (uint256)
    {
        return msg.value;
    }

    /// Transfers ETHs to given address.
    /// @param _to Recipient address.
    /// @param _amount Amount of ETHs to transfer.
    function __safeTransferTo(address payable _to, uint256 _amount)
        internal
        virtual override
    {
        payable(_to).transfer(_amount);
        emit Transfer(msg.sender, _amount);
    }  


    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory) 
        override public
        onlyDelegateCalls // => we don't want the logic base contract to be ever initialized
    {
        if (
            __proxiable().proxy == address(0)
                && __proxiable().implementation == address(0)
        ) {
            // a proxy is being initialized for the first time...
            __proxiable().proxy = address(this);
            _transferOwnership(msg.sender);
        } else {
            // only the owner can initialize:
            if (msg.sender != owner()) {
                revert("WitnetRequestBoardTrustlessDefault: not the owner");
            }
        }
        require(
            __proxiable().implementation != base(),
            "WitnetRequestBoardTrustlessDefault: already initialized"
        );
        require(
            address(blocks.board()) == address(this),
            "WitnetRequestBoardTrustlessDefault: blocks.board() counterfactual mismatch"
        );
        __proxiable().implementation = base();
        emit Upgraded(msg.sender, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _from == owner()
        );
    }


    // ================================================================================================================
    // --- Implementation of 'IWitnetRequestBoardV2' ------------------------------------------------------------------
    
    function class()
        external pure
        virtual override(WitnetUpgradableBase, IWitnetRequestBoardV2)
        returns (bytes4)
    {
        return type(IWitnetRequestBoardV2).interfaceId;
    }
    
    function estimateQueryReward(
            bytes32 radHash, 
            WitnetV2.RadonSLAv2 calldata slaParams,
            uint256 witEvmPrice,
            uint256 evmMaxGasPrice,
            uint256 evmCallbackGasLimit
        )
        external view
        virtual override
        returns (uint256)
    {
        uint _queryMaxResultSize = registry.lookupRadonRequestResultMaxSize(radHash);
        uint _queryTotalWits = (
            slaParams.witMinMinerFee * 3
                + slaParams.committeeSize * slaParams.witWitnessReward
        );
        return (
            witEvmPrice * _queryTotalWits
                + evmMaxGasPrice * ( 
                    _DDR_REPORT_QUERY_GAS_BASE
                        + _getSaveToStorageCost(2 + _queryMaxResultSize / 32)
                        + evmCallbackGasLimit
                        // TODO: + evmClaimQueryGasLimit
                )
        );
    }

    function readQueryBridgeData(bytes32 queryHash)
        external view
        virtual override
        queryExists(queryHash)
        returns (
            WitnetV2.QueryStatus status,
            uint256 weiEvmReward,
            uint256 weiEvmStake,
            bytes memory radBytecode,
            WitnetV2.RadonSLAv2 memory slaParams
        )
    {
        status = checkQueryStatus(queryHash);
        WitnetV2.Query storage __query = __query_(queryHash);
        WitnetV2.QueryRequest storage __request = __query.request;
        weiEvmReward = __query.weiReward;
        weiEvmStake = __query.weiStake;
        radBytecode = registry.bytecodeOf(__request.radHash);
        slaParams = WitnetV2.toRadonSLAv2(__request.packedSLA);
    }
    
    function readQueryBridgeStatus(bytes32 queryHash)
        external view
        virtual override
        returns (
            WitnetV2.QueryStatus status,
            uint256 weiEvmReward
        )
    {
        status = checkQueryStatus(queryHash);
        weiEvmReward = __query_(queryHash).weiReward;
    }

    function readQuery(bytes32 queryHash)
        external view
        virtual override
        queryExists(queryHash)
        returns (WitnetV2.Query memory)
    {
        return __query_(queryHash);
    }

    function readQueryEvmReward(bytes32 queryHash)
        external view
        virtual override
        queryExists(queryHash)
        returns (uint256)
    {
        return __query_(queryHash).weiReward;
    }

    function readQueryCallback(bytes32 queryHash)
        external view
        virtual override
        queryExists(queryHash)
        returns (WitnetV2.QueryCallback memory)
    {
        return __query_(queryHash).callback;
    }

    function readQueryRequest(bytes32 queryHash)
        external view
        virtual override
        queryExists(queryHash)
        returns (bytes32, WitnetV2.RadonSLAv2 memory sla)
    {
        return (
            __request_(queryHash).radHash,
            WitnetV2.toRadonSLAv2(__request_(queryHash).packedSLA)
        );
    }
    
    function readQueryReport(bytes32 queryHash)
        external view
        virtual override
        queryExists(queryHash)
        returns (WitnetV2.QueryReport memory)
    {
        return __query_(queryHash).report;
    }

    function readQueryResult(bytes32 queryHash)
        external view
        virtual override
        returns (Witnet.Result memory)
    {
        return Witnet.resultFromCborBytes(__report_(queryHash).tallyCborBytes);
    }

    function checkQueryStatus(bytes32 queryHash)
        public view
        virtual override
        returns (WitnetV2.QueryStatus)
    {
        WitnetV2.Query storage __query = __query_(queryHash);
        if (__query.reporter != address(0)) {
            if (__query.disputes.length > 0) {
                // disputed or finalized
                if (blocks.getLastBeaconEpoch() > __query.reportEpoch) {
                    return WitnetV2.QueryStatus.Finalized;
                } else {
                    return WitnetV2.QueryStatus.Disputed;
                }
            } else {
                // reported or finalized
                return WitnetV2.checkQueryReportStatus(
                    __query.reportEpoch, 
                    blocks.getCurrentEpoch()
                );
            }
        } else if (__query.from != address(0)) {
            // posted, delayed or expired
            return WitnetV2.checkQueryPostStatus(
                __query.postEpoch,
                blocks.getCurrentEpoch()
            );
        } else {
            return WitnetV2.QueryStatus.Void;
        }
    }
    
    function checkQueryResultStatus(bytes32 queryHash)
        public view
        virtual override
        returns (Witnet.ResultStatus)
    {
        WitnetV2.QueryStatus _queryStatus = checkQueryStatus(queryHash);
        if (_queryStatus == WitnetV2.QueryStatus.Finalized) {
            // determine whether reported result is an error by peeking the first byte
            return (__report_(queryHash).tallyCborBytes[0] == bytes1(0xd8) 
                ? Witnet.ResultStatus.Error
                : Witnet.ResultStatus.Ready
            );
        } else if (_queryStatus == WitnetV2.QueryStatus.Expired) {
            return Witnet.ResultStatus.Expired;
        } else if (_queryStatus == WitnetV2.QueryStatus.Void) {
            return Witnet.ResultStatus.Void;
        } else {
            return Witnet.ResultStatus.Awaiting;
        }
    }
    
    function checkQueryResultError(bytes32 queryHash)
        external view
        virtual override
        returns (Witnet.ResultError memory)
    {
        Witnet.ResultStatus _resultStatus = checkQueryResultStatus(queryHash);
        if (_resultStatus == Witnet.ResultStatus.Awaiting) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.BoardUnsolvedQuery,
                reason: "Witnet: Board: pending query"
            });
        } else if (_resultStatus == Witnet.ResultStatus.Expired) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.BoardExpiredQuery,
                reason: "Witnet: Board: expired query"
            });
        } else if (_resultStatus == Witnet.ResultStatus.Void) {
            return Witnet.ResultError({
                code: Witnet.ResultErrorCodes.Unknown,
                reason: "Witnet: Board: unknown query"
            });
        } else {
            try WitnetErrorsLib.resultErrorFromCborBytes(__report_(queryHash).tallyCborBytes)
                returns (Witnet.ResultError memory _error)
            {
                return _error;
            }
            catch Error(string memory _reason) {
                return Witnet.ResultError({
                    code: Witnet.ResultErrorCodes.BoardUndecodableError,
                    reason: string(abi.encodePacked("Witnet: Board: undecodable error: ", _reason))
                });
            }
            catch (bytes memory) {
                return Witnet.ResultError({
                    code: Witnet.ResultErrorCodes.BoardUndecodableError,
                    reason: "Witnet: Board: undecodable error: assertion failed"
                });
            }
        }
    }
    
    function postQuery(
            bytes32 radHash,
            WitnetV2.RadonSLAv2 calldata slaParams
        )
        external payable
        virtual override
        returns (bytes32 _queryHash)
    {
        return postQuery(
            radHash,
            slaParams,
            IWitnetRequestCallback(address(0)), 
            0
        );
    }

    function postQuery(
            bytes32 radHash,
            WitnetV2.RadonSLAv2 calldata slaParams,
            IWitnetRequestCallback queryCallback,
            uint256 queryCallbackGas
        )
        public payable
        virtual override
        returns (bytes32 queryHash)
    {
        require(
            WitnetV2.isValid(slaParams),
            "WitnetRequestBoardTrustlessDefault: invalid SLA"
        );
        bytes32 packedSLA = WitnetV2.pack(slaParams);
        uint256 postEpoch = blocks.getCurrentEpoch();
        queryHash = keccak256(abi.encodePacked(
            DDR_QUERY_TAG,
            radHash,
            packedSLA,
            postEpoch
        ));
        WitnetV2.Query storage __query = __storage().queries[queryHash];
        require(
            __query.postEpoch == 0,
            "WitnetRequestBoardTrustlessDefault: already posted"
        );
        __query.postEpoch = postEpoch;
        __query.weiReward = msg.value;
        __query.weiStake = DDR_REPORT_QUERY_MIN_STAKE_WEI();
        __query.request = WitnetV2.QueryRequest({
            radHash: radHash, 
            packedSLA: packedSLA
        });
        if (address(queryCallback) != address(0)) {
            require(
                queryCallbackGas >= 50000, 
                "WitnetRequestBoardTrustlessDefault: insufficient callback gas"
            );
            __query.callback = WitnetV2.QueryCallback({
                addr: address(queryCallback),
                gas: queryCallbackGas
            });
        }
        emit PostedQuery(
            msg.sender,
            queryHash,
            address(queryCallback)
        );
    }

    function deleteQuery(bytes32 queryHash)
        external
        virtual override
    {
        WitnetV2.Query storage __query = __query_(queryHash);
        address _requester = __query.from;
        address _reporter = __query.reporter;
        uint256 _weiReward = __query.weiReward;
        uint256 _weiStake = __query.weiStake;
        require(
            msg.sender == __query.from,
            "WitnetRequestBoardTrustlessDefault: not the requester"
        );
        WitnetV2.QueryStatus _queryStatus = checkQueryStatus(queryHash);
        if (
            _queryStatus == WitnetV2.QueryStatus.Finalized
                || _queryStatus == WitnetV2.QueryStatus.Expired
        ) {
            delete __query.request;//?
            delete __query.report;//?
            delete __query.callback;//?
            delete __query.disputes;//?
            delete __storage().queries[queryHash];
            emit DeletedQuery(msg.sender, queryHash);
            if (_weiReward > 0) {
                if (_queryStatus == WitnetV2.QueryStatus.Expired) {
                    __safeTransferTo(payable(_requester), _weiReward);
                } else {
                    __receive(_reporter, _weiReward);
                }
            }
            if (_weiStake > 0) {
                __unstake(_reporter, _weiStake);
            }
        } else {
            revert("WitnetRequestBoardTrustlessDefault: not in current status");
        }
    }

    function reportQuery(
            bytes32 queryHash,
            bytes calldata relayerSignature,
            WitnetV2.QueryReport calldata queryReport
        )
        public 
        virtual override
        stakes(queryHash)
    {
        WitnetV2.Query storage __query = __query_(queryHash);
        WitnetV2.QueryStatus _queryStatus = checkQueryStatus(queryHash);
        if (
            _queryStatus == WitnetV2.QueryStatus.Delayed
            || (
                _queryStatus == WitnetV2.QueryStatus.Posted
                    && Witnet.recoverAddr(queryHash, relayerSignature) == msg.sender
                    && msg.sender == queryReport.relayer
            )
        ) {
            __query.reporter = msg.sender;
        } else {
            revert("WitnetRequestBoardTrustlessDefault: unauthorized report");
        }
        uint _tallyBeaconIndex = WitnetV2.beaconIndexFromEpoch(queryReport.tallyEpoch);
        uint _postBeaconIndex = WitnetV2.beaconIndexFromEpoch(__query.postEpoch);
        require(
            _tallyBeaconIndex >= _postBeaconIndex && _tallyBeaconIndex <= _postBeaconIndex + 1, 
            "WitnetRequestBoardTrustlessDefault: too late tally"
        );
        __query.reportEpoch = blocks.getCurrentEpoch();
        __query.report = queryReport;
        WitnetV2.QueryCallback storage __callback = __query.callback;
        if (__callback.addr != address(0)) {
            IWitnetRequestCallback(__callback.addr).settleWitnetQueryReport{gas: __callback.gas}(
                queryHash,
                queryReport
            );
        }
        emit ReportedQuery(
            msg.sender,
            queryHash,
            __callback.addr
        );
    }

    function reportQueryBatch(
            bytes32[] calldata hashes,
            bytes[] calldata signatures,
            WitnetV2.QueryReport[] calldata reports
        )
        external 
        virtual override
    {
        require(
            hashes.length == reports.length
                && hashes.length == signatures.length,
            "WitnetRequestBoardTrustlessDefault: arrays mismatch"
        );
        for (uint _ix = 0; _ix < hashes.length; _ix ++) {
            WitnetV2.QueryStatus _status = checkQueryStatus(hashes[_ix]);
            if (_status == WitnetV2.QueryStatus.Posted || _status == WitnetV2.QueryStatus.Delayed) {
                reportQuery(hashes[_ix], signatures[_ix], reports[_ix]);
            }
        }
    }

    function disputeQuery(
            bytes32 queryHash,
            WitnetV2.QueryReport calldata queryReport
        )
        external
        virtual override
        stakes(queryHash)
    {
        WitnetV2.QueryStatus queryStatus = checkQueryStatus(queryHash);
        if (
            queryStatus == WitnetV2.QueryStatus.Reported
                || queryStatus == WitnetV2.QueryStatus.Delayed
                || queryStatus == WitnetV2.QueryStatus.Disputed
        ) {
            WitnetV2.Query storage __query = __query_(queryHash);
            uint _tallyBeaconIndex = WitnetV2.beaconIndexFromEpoch(queryReport.tallyEpoch);
            uint _postBeaconIndex = WitnetV2.beaconIndexFromEpoch(__query.postEpoch);
            require(
                _tallyBeaconIndex >= _postBeaconIndex
                    && _tallyBeaconIndex <= _postBeaconIndex + 1,
                "WitnetRequestBoardTrustlessDefault: too late tally"
            );
            __query.disputes.push(WitnetV2.QueryDispute({
                disputer: msg.sender,
                report: queryReport
            }));
            if (__query.disputes.length == 1 && __query.reporter != address(0)) {
                // upon first dispute, append reporter's tallyHash
                __storage().suitors[__query.report.tallyHash(queryHash)] = Suitor({
                    index: 0,
                    queryHash: queryHash
                });
            }
            bytes32 _tallyHash = queryReport.tallyHash(queryHash);
            require(
                __storage().suitors[_tallyHash].queryHash == bytes32(0),
                "WitnetRequestBoardTrustlessDefault: replayed dispute"
            );
            __storage().suitors[_tallyHash] = Suitor({
                index: __query.disputes.length,
                queryHash: queryHash
            });
            // settle query dispute on WitnetBlocks
            blocks.disputeQuery(queryHash, _tallyBeaconIndex);
            // emit event
            emit DisputedQuery(
                msg.sender, 
                queryHash, 
                _tallyHash
            );
        } else {
            revert("WitnetRequestBoardTrustlessDefault: not disputable");
        }
    }

    function claimQueryReward(bytes32 queryHash)
        external
        virtual override
        queryInStatus(queryHash, WitnetV2.QueryStatus.Finalized)
        returns (uint256 _weiReward)
    {
        WitnetV2.Query storage __query = __query_(queryHash);
        require(
            msg.sender == __query.reporter,
            "WitnetRequestBoardTrustlessDefault: not the reporter"
        );
        _weiReward = __query.weiReward;
        if (_weiReward > 0) {
            __query.weiReward = 0;
            __receive(__query.reporter, _weiReward);
        } else {
            revert("WitnetRequestBoardTrustlessDefault: already claimed");
        }
        uint _weiStake = __query.weiStake;
        if (_weiStake > 0) {
            __query.weiStake = 0;
            __unstake(__query.reporter, _weiStake);
        }
    }

    function determineQueryTallyHash(bytes32)
        virtual override
        external
        returns (
            bytes32,
            uint256
        )
    {
        require(
            msg.sender == address(blocks),
            "WitnetRequestBoardTrustlessDefault: unauthorized"
        );
        // TODO
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _getSaveToStorageCost(uint256 words) virtual internal pure returns (uint256) {
        return words * 20000;
    }

    function _queryNotInStatusRevertMessage(WitnetV2.QueryStatus queryStatus)
        internal pure
        returns (string memory)
    {
        string memory _reason;
        if (queryStatus == WitnetV2.QueryStatus.Posted) {
            _reason = "Posted";
        } else if (queryStatus == WitnetV2.QueryStatus.Reported) {
            _reason = "Reported";
        } else if (queryStatus == WitnetV2.QueryStatus.Disputed) {
            _reason = "Disputed";
        } else if (queryStatus == WitnetV2.QueryStatus.Expired) {
            _reason = "Expired";
        } else if (queryStatus == WitnetV2.QueryStatus.Finalized) {
            _reason = "Finalized";
        } else {
            _reason = "expected";
        }
        return string(abi.encodePacked(
            "WitnetRequestBoardTrustlessDefault: not in ", 
            _reason,
            " status"
        ));
    }

    function _max(uint a, uint b) internal pure returns (uint256) {
        unchecked {
            if (a >= b) {
                return a;
            } else {
                return b;
            }
        }
    }

}
