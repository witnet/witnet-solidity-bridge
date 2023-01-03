// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../../WitnetUpgradableBase.sol";
import "../../../WitnetRequestBoardV2.sol";
import "../../../data/WitnetRequestBoardV2Data.sol";

/// @title Witnet Request Board "trustless" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitnetRequestBoardTrustlessBase
    is 
        WitnetUpgradableBase,
        WitnetRequestBoardV2,
        WitnetRequestBoardV2Data
{
    using ERC165Checker for address;
    using WitnetV2 for bytes;
    using WitnetV2 for uint256;

    modifier onlyDrPostReporter(bytes32 _drHash) {
        address _expectedReporter = __drPostRequest(_drHash).reporter;
        if (
            _msgSender() != _expectedReporter
                && _expectedReporter != address(0)
        ) {
            revert IWitnetRequests.DrPostOnlyReporter(
                _drHash,
                _expectedReporter
            );
        }
        _;
    }

    modifier onlyDrPostRequester(bytes32 _drHash) {
        WitnetV2.DrPostRequest storage __post = __drPostRequest(_drHash);
        address _requester = __drPostRequest(_drHash).requester;
        if (_msgSender() != _requester) {
            revert IWitnetRequests.DrPostOnlyRequester(_drHash, _requester);
        }
        _;
    }
    
    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        Payable(address(0x0))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.boards.v2"
        )
    {}

    receive() external payable override {
        revert("WitnetRequestBoardTrustlessBase: no transfers accepted");
    }

    function blocks() override external view returns (IWitnetBlocks) {
        return __board().blocks;
    }

    function bytecodes() override external view returns (IWitnetBytecodes) {
        return __board().bytecodes;
    }

    function decoder() override external view returns (IWitnetDecoder) {
        return __board().decoder;
    }

    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override(WitnetUpgradableBase, ERC165)
      returns (bool)
    {
        return _interfaceId == type(WitnetRequestBoardV2).interfaceId
            || _interfaceId == type(IWitnetRequestsAdmin).interfaceId
            || super.supportsInterface(_interfaceId);
    }


    // ================================================================================================================
    // --- Internal virtual methods -----------------------------------------------------------------------------------

    // function _cancelDeadline(uint256 _postEpoch) internal view virtual returns (uint256);
    // function _reportDeadlineEpoch(uint256 _postEpoch) internal view virtual returns (uint256);    
    // function _selectReporter(bytes32 _drHash) internal virtual view returns (address);


    // ================================================================================================================
    // --- Overrides 'Ownable2Step' -----------------------------------------------------------------------------------

    /// Returns the address of the pending owner.
    function pendingOwner()
        public view
        virtual override
        returns (address)
    {
        return __board().pendingOwner;
    }

    /// Returns the address of the current owner.
    function owner()
        public view
        virtual override
        returns (address)
    {
        return __board().owner;
    }

    /// Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        public
        virtual override
        onlyOwner
    {
        __board().pendingOwner = _newOwner;
        emit OwnershipTransferStarted(owner(), _newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`_newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    function _transferOwnership(address _newOwner)
        internal
        virtual override
    {
        delete __board().pendingOwner;
        address _oldOwner = owner();
        if (_newOwner != _oldOwner) {
            __board().owner = _newOwner;
            emit OwnershipTransferred(_oldOwner, _newOwner);
        }
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
    function _safeTransferTo(address payable _to, uint256 _amount)
        internal
        virtual override
        nonReentrant
    {
        payable(_to).transfer(_amount);
    } 


    // ================================================================================================================
    // --- Overrides 'Upgradable' -------------------------------------------------------------------------------------

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Must fail when trying to initialize same instance more than once.
    function initialize(bytes memory _initData) 
        public
        virtual override
    {
        address _owner = __board().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            __board().owner = _owner;
        } else {
            // only owner can initialize:
            if (msg.sender != _owner) revert WitnetUpgradableBase.OnlyOwner(_owner);
        }

        if (__board().serviceTag == bytes4(0)) {
            __setServiceTag();
        }

        if (__board().base != address(0)) {
            // current implementation cannot be initialized more than once:
            if(__board().base == base()) revert WitnetUpgradableBase.AlreadyInitialized(base());
        }        
        __board().base = base();

        emit Upgraded(msg.sender, base(), codehash(), version());

        // Parse optional input addresses array:
        address[] memory _refs = abi.decode(_initData, (address[]));
        if (_refs.length > 0 && _refs[0] != address(0)) setBlocks(_refs[0]);
        if (_refs.length > 1 && _refs[1] != address(0)) setBytecodes(_refs[1]);
        if (_refs.length > 2 && _refs[2] != address(0)) setDecoder(_refs[2]);

// // All complying references must be provided:
// if (address(__board().blocks) == address(0)) {
//     revert WitnetUpgradableBase.NotCompliant(type(IWitnetBlocks).interfaceId);
// } else if (address(__board().bytecodes) == address(0)) {
//     revert WitnetUpgradableBase.NotCompliant(type(IWitnetBytecodes).interfaceId);
// } else if (address(__board().decoder) == address(0)) {
//     revert WitnetUpgradableBase.NotCompliant(type(IWitnetDecoder).interfaceId);
// }

        // Set deliveryTag if not done yet:
        if (__board().serviceTag == bytes4(0)) {
            __setServiceTag();
        }
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = __board().owner;
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }


    // ================================================================================================================
    // --- Base implementation of 'IWitnetRequestsAdmin' --------------------------------------------------------------

    function setBlocks(address _contractAddr)
        public
        virtual override
        onlyOwner
    {
        if (isUpgradable()) {
            if (!_contractAddr.supportsInterface(type(IWitnetBlocks).interfaceId)) {
                revert WitnetUpgradableBase.NotCompliant(type(IWitnetBlocks).interfaceId);
            }
            __board().blocks = IWitnetBlocks(_contractAddr);
            emit SetBlocks(_msgSender(), _contractAddr);
        } else {
            revert WitnetUpgradableBase.NotUpgradable(address(this));
        }
    }

    function setBytecodes(address _contractAddr)
        public
        virtual override
        onlyOwner
    {
        if (!_contractAddr.supportsInterface(type(IWitnetBytecodes).interfaceId)) {
            revert WitnetUpgradableBase.NotCompliant(type(IWitnetBytecodes).interfaceId);
        }
        __board().bytecodes = IWitnetBytecodes(_contractAddr);
        emit SetBytecodes(_msgSender(), _contractAddr);
    }

    function setDecoder(address _contractAddr)
        public
        virtual override
        onlyOwner
    {
        if (!_contractAddr.supportsInterface(type(IWitnetDecoder).interfaceId)) {
            revert WitnetUpgradableBase.NotCompliant(type(IWitnetDecoder).interfaceId);
        }
        __board().decoder = IWitnetDecoder(_contractAddr);
        emit SetDecoder(_msgSender(), _contractAddr);
    }


    // ================================================================================================================
    // --- Base implementation of read-only methods in 'IWitnetRequests' ----------------------------------------------    

    function estimateBaseFee(
            bytes32 _drRadHash,
            uint256 _gasPrice,
            bytes32 _drSlaHash,
            uint256 _witPrice
        )
        public view
        override
        returns (uint256)
    {
        return (
            estimateReportFee(_drRadHash, _gasPrice)
                // TODO: + __board().bytecodes.lookupDrSlaReward(_drSlaHash) * _witPrice
        );
    }

    function estimateReportFee(bytes32 _drRadHash, uint256 _gasPrice)
        public view
        virtual override
        returns (uint256)
    {
        revert("WitnetRequestBoardTrustlessBase: not yet implemented");
    }

    function getDrPost(bytes32 _drHash)
        public view
        virtual override
        returns (WitnetV2.DrPost memory)
    {
        return __board().posts[_drHash];
    }

    function getDrPostEpoch(bytes32 _drHash)
        public view
        virtual override
        returns (uint256)
    {
        return __drPost(_drHash).request.epoch;
    }

    function getDrPostResponse(bytes32 _drHash)
        public view 
        virtual override
        returns (WitnetV2.DrPostResponse memory)
    {
        return __drPostResponse(_drHash);
    }
    
    function getDrPostStatus(bytes32 _drHash)
        public view 
        virtual override
        returns (WitnetV2.DrPostStatus)
    {
        return _getDrPostStatus(_drHash);
    }

    function readDrPostResultBytes(bytes32 _drHash)
        public view
        virtual override
        drPostNotDeleted(_drHash)
        returns (bytes memory)
    {
        return __drPostResponse(_drHash).drTallyResultCborBytes;
    }

    function serviceStats()
        public view
        virtual override
        returns (IWitnetRequests.Stats memory)
    {
        return __board().serviceStats;
    }
    
    function serviceTag()
        public view
        virtual override
        returns (bytes4)
    {
        return __board().serviceTag;
    }


    // ================================================================================================================
    // --- Base implementation of state-modifying methods in 'IWitnetRequests' ----------------------------------------

    function deleteDrPost(bytes32 _drHash)
        external
        virtual override
    {
        if (!_canDrPostBeDeletedFrom(_drHash, _msgSender())){
            revert WitnetV2.Unauthorized(_msgSender());
        }
        __deleteDrPost(_drHash);
        emit DrPostDeleted(_msgSender(), _drHash);
    }
    
    function deleteDrPostRequest(bytes32 _drHash)
        public
        virtual override
    {
        if (!_canDrPostBeDeletedFrom(_drHash, _msgSender())){
            revert WitnetV2.Unauthorized(_msgSender());
        }
        __deleteDrPostRequest(_drHash);
    }

    function disputeDrPost(bytes32 _drHash)
        external payable
        virtual override
        // stakes(_disputeStake(), _disputeDeadlineBlock())
    {
        // TODO
        // WitnetV2.DrPostStatus _currentStatus = _getDrPostStatus(_drHash);
        // WitnetV2.DrPostResponse storage __response = __drPostResponse(_drHash);
        // if (
        //     _currentStatus == WitnetV2.DrPostStatus.Posted
        //         || _currentStatus = WitnetV2.DrPostStatus.Reported
        // ) {
        //     if (__response.reporter != address(0)) {
        //         if (_msgSender() == __response.reporter) {
        //             revert IWitnetRequests.DrPostBadDisputer(
        //                 _drHash,
        //                 _msgSender()
        //             );
        //         }
        //     }
        //     // TODO: check escrow value
        //     __response = WitnetV2.DrPostResponse({
        //         disputer: _msgSender(),
        //         reporter: __response.reporter,
        //         escrowed: _getMsgValue(),
        //         drCommitTxEpoch: 0,
        //         drTallyTxEpoch: 0,
        //         drTallyTxHash: bytes32(0),
        //         cborBytes: bytes("") // Witnet.Precompiled.NoWitnetResponse
        //     });
        //     emit DrPostDisputed(_msgSender(), _drHash);
        // } 
        // else {
        //     revert IWitnetRequests.DrPostBadMood(
        //         _drHash,
        //         _currentStatus
        //     );
        // }
        // __board.serviceStats.totalDisputes ++;
    }

    function postDr(
            bytes32 _drRadHash,
            bytes32 _drSlaHash,
            uint256
        )
        external payable
        returns (bytes32 _drHash)
    {
        // TODO
        // Calculate current epoch in Witnet terms:
        uint256 _currentEpoch = block.timestamp; // TODO: .toEpoch();

        // Calculate data request delivery tag:
        bytes8 _drDeliveryTag = bytes8(keccak256(abi.encode(
            _msgSender(),
            _drRadHash,
            _drSlaHash,
            _currentEpoch,            
            ++ __board().serviceStats.totalPosts
        )));
        _drDeliveryTag |= bytes8(serviceTag());

        // Calculate data request post hash:
        _drHash = Witnet.hash(abi.encodePacked(
            _drRadHash,
            _drSlaHash,
            _drDeliveryTag
        ));

        // Check minimum base fee is covered:
        // uint256 _minBaseFee = estimateBaseFee(
        //     _drRadHash,
        //     _getGasPrice(),
        //     _drSlaHash,
        // );
        // if (_getMsgValue() < _minBaseFee) {
        //     revert IWitnetRequests.DrPostLowReward(_drHash, _minBaseFee, _getMsgValue());
        // }

        // Save DrPost in storage:
        WitnetV2.DrPost storage __dr = __drPost(_drHash);
        __dr.block = block.number;
        __dr.status = WitnetV2.DrPostStatus.Posted;
        __dr.request = WitnetV2.DrPostRequest({
            epoch: _currentEpoch,
            requester: _msgSender(),
            reporter: msg.sender, // TODO: _selectReporter(),
            radHash: _drRadHash,
            slaHash: _drSlaHash,
            weiReward: _getMsgValue()
        });
        emit DrPost(msg.sender, _drHash);//__drPostRequest(_drHash));
    }

    function reportDrPost(
            bytes32 _drHash,
            uint256 _drCommitTxEpoch,
            uint256 _drTallyTxEpoch,
            bytes32 _drTallyTxHash,
            bytes calldata _drTallyResultCborBytes
        )
        external payable
        virtual override
        drPostInStatus(_drHash, WitnetV2.DrPostStatus.Posted)
        // stakes(_disputeStake(), _disputeDeadlineBlock())
    {
        // TODO
        // address _disputer = address(0);
        // uint256 _currentEpoch = block.timestamp.toEpoch();
        // uint256 _drPostEpoch = _getDrPostEpoch(_drHash);
        // if (_currentEpoch <= _reportDeadlineEpoch(_drHash)) {
        //     if (_msgSender() != __drPostRequest(_drHash).to) {
        //         revert DrPostOnlyReporter(__drPostRequest(_drHash).to);
        //     }
        // } else {
        //     _disputer = _msgSender();
        // }
        // if (
        //     _drCommitTxEpoch <= _drPostEpoch
        //         || _drTallyTxEpoch <= _drCommitTxEpoch
        // ) {
        //     revert DrPostBadEpochs(
        //         _drHash,
        //         _drPostEpoch,
        //         _drCommitTxEpoch,
        //         _drTallyTxEpoch
        //     );
        // }
        // __drPostResponse(_drHash) = WitnetV2.DrPostResponse({
        //     disputer: _disputer,
        //     reporter: _disputer == address(0) ? _msgSender() : address(0),
        //     escrowed: _getMsgValue(),
        //     drCommitTxEpoch: _drCommitTxEpoch,
        //     drTallyTxEpoch: _drTallyTxEpoch,
        //     drTallyTxHash: _drTallyTxHash,
        //     drTallyResultCborBytes: _drTallyResultCborBytes
        // });
        // __board().serviceStats.totalReports ++;
    }
    
    function verifyDrPost(
            bytes32 _drHash,
            uint256 _drCommitTxEpoch,
            uint256 _drTallyTxEpoch,
            uint256 _drTallyTxIndex,
            bytes32 _blockDrTallyTxsRoot,            
            bytes32[] calldata _blockDrTallyTxHashes,
            bytes calldata _drTallyTxBytes
        )
        external payable
        virtual override
    {
        // TODO
        // WitnetV2.DrPostStatus _currentStatus = _getDrPostStatus(_drHash);
        // WitnetV2.DrPostResponse storage __response = __drPostResponse(_drHash);
        // address _bannedSender = _currentStatus == WitnetV2.DrPostStatus.Reported 
        //     ? __response.reporter
        //     : _currentStatus == WitnetV2.DrPostStatus.Disputed
        //         ? __response.disputer
        //         : address(0)
        // ;
        // if (_bannedSender == address(0)) {
        //     revert IWitnetRequests.DrPostBadMood(
        //         _drHash,
        //         _currentStatus
        //     );
        // } else if (_msgSender() == _bannedSender) {
        //     revert IWitnetRequests.DrPostBadDisputer(
        //         _drHash,
        //         _msgSender()
        //     );
        // } else {
        //     bytes memory _drTallyTxResult;
        //     // TODO: _drTallyTxResult = _verifyDrPost(...);
        //     __response = WitnetV2.DrPostResponse({
        //         disputer: _currentStatus == WitnetV2.DrPostStatus.Reported ? _msgSender() : __response.disputer,
        //         reporter: _currentStatus == WitnetV2.DrPostStatus.Disputed ? _msgSender() : __response.reporter,
        //         escrowed: __response.escrowed,
        //         drCommitTxEpoch: _drCommitTxEpoch,
        //         drTallyTxEpoch: _drTallyTxEpoch,
        //         drTallyTxHash: _blockDrTallyTxHashes[_drTallyTxIndex],
        //         drTallyTxResult: _drTallyTxResult
        //     });
        //     emit DrPostVerified(
        //         _msgSender(),
        //         _drHash
        //     );
        //     if (_currentStatus == WitnetV2.DrPostStatus.Reported) {
        //         __board().serviceStats.totalDisputes ++;
        //     } else {
        //         __board().serviceStats.totalReports ++;
        //     }
        // }
        // // TODO: __contextSlash(_bannedSender);
    }

    function upgradeDrPostReward(bytes32 _drHash)
        public payable
        virtual override
        drPostInStatus(_drHash, WitnetV2.DrPostStatus.Posted)
    {
        if (_getMsgValue() > 0) {
            __drPostRequest(_drHash).weiReward += _getMsgValue();
            emit DrPostUpgraded(
                _msgSender(),
                _drHash,
                __drPostRequest(_drHash).weiReward
            );
            __board().serviceStats.totalUpgrades ++;
        }
    }

}