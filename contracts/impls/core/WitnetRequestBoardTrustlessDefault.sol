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
    uint256 immutable internal __reportQueryMinGas;

    constructor(
            WitnetBlocks _blocks,
            WitnetRequestFactory _factory,
            uint256 _reportQueryMinGas,
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
        __reportQueryMinGas = _reportQueryMinGas;
    }

    /// Asserts the given query is currently in some specific status.
    modifier queryInStatus(
            bytes32 queryHash,
            WitnetV2.QueryStatus queryStatus
        )
    {
        require(
            _statusOf(queryHash, blocks) == queryStatus,
            _statusOfRevertMessage(queryStatus)
        );
        _;
    }

    modifier stakes(bytes32 queryHash) {
        __stake(
            msg.sender,
            __query_(queryHash).weiReward
                * WitnetV2.toRadonSLAv2EvmCollateralRatio(
                    __request_(queryHash).packedSLA
                )
        );
        _;
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
    
    function nonce()
        external view
        virtual override
        returns (uint256)
    {
        return __storage().nonce;
    }

    function tag()
        public view 
        virtual override
        returns (bytes4)
    {
        return bytes4(keccak256(abi.encodePacked(
            "evm:",
            Witnet.toString(block.chainid),
            ":",
            Witnet.toHexString(address(this))
        )));
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
            slaParams.witMinerFee * 3
                + slaParams.committeeSize * slaParams.witWitnessReward
        );
        return (
            witEvmPrice * _queryTotalWits
                + evmMaxGasPrice * ( 
                    __reportQueryMinGas
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
            bytes memory radBytecode,
            WitnetV2.RadonSLAv2 memory slaParams
        )
    {
        status = _statusOf(queryHash, blocks);
        WitnetV2.Query storage __query = __query_(queryHash);
        WitnetV2.QueryRequest storage __request = __query.request;
        weiEvmReward = __query.weiReward;
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
        status = _statusOf(queryHash, blocks);
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
        return Witnet.resultFromCborBytes(__report_(queryHash).resultCborBytes);
    }

    function checkQueryStatus(bytes32 queryHash)
        external view
        virtual override
        returns (WitnetV2.QueryStatus)
    {
        return _statusOf(queryHash, blocks);
    }
    
    function checkQueryResultStatus(bytes32 queryHash)
        public view
        virtual override
        returns (Witnet.ResultStatus)
    {
        WitnetV2.QueryStatus _queryStatus = _statusOf(queryHash, blocks);
        if (
            _queryStatus == WitnetV2.QueryStatus.Posted
                || _queryStatus == WitnetV2.QueryStatus.Delayed
        ) {
            return Witnet.ResultStatus.Awaiting;
        } else if (_queryStatus == WitnetV2.QueryStatus.Reported) {
            // determine whether reported result is an error by peeking the first byte
            return (__report_(queryHash).resultCborBytes[0] == bytes1(0xd8) 
                ? Witnet.ResultStatus.Error
                : Witnet.ResultStatus.Ready
            );
        } else if (_queryStatus == WitnetV2.QueryStatus.Expired) {
            return Witnet.ResultStatus.Expired;
        } else {
            return Witnet.ResultStatus.Void;
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
            try WitnetErrorsLib.resultErrorFromCborBytes(__report_(queryHash).resultCborBytes)
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
        queryHash = keccak256(abi.encodePacked(
            block.chainid,
            blockhash(block.number - 1), 
            __storage().nonce ++
        ));
        WitnetV2.Query storage __query = __storage().queries[queryHash];
        __query.epoch = blocks.getCurrentBeaconIndex();
        __query.weiReward = msg.value;
        __query.request = WitnetV2.QueryRequest({
            radHash: radHash, 
            packedSLA: WitnetV2.pack(slaParams)
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
        require(
            msg.sender == __query.from,
            "WitnetRequestBoardTrustlessDefault: not the requester"
        );
        WitnetV2.QueryStatus _queryStatus = _statusOf(queryHash, blocks);
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
        } else {
            revert("WitnetRequestBoardTrustlessDefault: not in current status");
        }
    }

    function reportQuery(
            bytes32 queryHash,
            WitnetV2.QueryReport calldata queryReport
        )
        public 
        virtual override
        stakes(queryHash)
        queryInStatus(queryHash, WitnetV2.QueryStatus.Posted)
    {
        WitnetV2.Query storage __query = __query_(queryHash);
        WitnetV2.QueryCallback storage __callback = __query.callback;
        {
            __query.reporter = msg.sender;
            __query.report = queryReport;
        }
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
            bytes32[] calldata queryHashes, 
            WitnetV2.QueryReport[] calldata queryReports
        )
        external 
        virtual override
    {
        require(
            queryHashes.length == queryReports.length,
            "WitnetRequestBoardTrustlessDefault: length mismatch"
        );
        for (uint _ix = 0; _ix < queryHashes.length; _ix ++) {
            require(
                _statusOf(queryHashes[_ix], blocks) == WitnetV2.QueryStatus.Posted,
                string(abi.encodePacked(
                    "WitnetRequestBoardTrustlessDefault: not in Posted status: index ",
                    Witnet.toString(_ix)
                ))
            );
            reportQuery(queryHashes[_ix], queryReports[_ix]);
        }
    }

    function claimQueryReward(bytes32 queryHash)
        external
        virtual override
        queryInStatus(queryHash, WitnetV2.QueryStatus.Finalized)
        returns (uint256 _weiReward)
    {
        WitnetV2.Query storage __query = __query_(queryHash);
        _weiReward = __query.weiReward;
        require(
            msg.sender == __query.reporter,
            "WitnetRequestBoardTrustlessDefault: not the reporter"
        );
        require(
            __query.weiReward > 0,
            "WitnetRequestBoardTrustlessDefault: already claimed"
        );
        __query.weiReward = 0;
        __receive(__query.reporter, _weiReward);
    }

    function disputeQuery(
            bytes32 queryHash,
            WitnetV2.QueryReport calldata queryReport
        )
        external
        virtual override
        stakes(queryHash)
    {
        WitnetV2.QueryStatus queryStatus = _statusOf(queryHash, blocks);
        if (
            queryStatus == WitnetV2.QueryStatus.Reported
                || queryStatus == WitnetV2.QueryStatus.Delayed
                || queryStatus == WitnetV2.QueryStatus.Disputed
        ) {
            WitnetV2.Query storage __query = __query_(queryHash);
            __query.disputes.push(WitnetV2.QueryDispute({
                disputer: msg.sender,
                report: queryReport
            }));
            emit DisputedQuery(msg.sender, queryHash);
        } else {
            revert("WitnetRequestBoardTrustlessDefault: not in this status");
        }
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _getSaveToStorageCost(uint256 words) virtual internal pure returns (uint256) {
        return words * 20000;
    }

}
