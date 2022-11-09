// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetRequestBoardTrustlessBase.sol";
import "../../../data/WitnetReporting1Data.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitnetRequestBoardTrustlessReporting1
    is 
        WitnetRequestBoardTrustlessBase,
        WitnetReporting1Data
{
    modifier onlySignedUpReporters {
        if (!isSignedUpReporter(_msgSender())) {
            revert WitnetV2.Unauthorized(_msgSender());
        }
        _;
    }

    modifier onlyExpectedReporterFor(bytes32 _drHash) {
        if (_msgSender() != __drPostRequest(_drHash).reporter) {
            revert WitnetV2.Unauthorized(_msgSender());
        }
        _;
    }

    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetRequestBoardTrustlessBase(_upgradable, _versionTag)
    {}

    // ================================================================================================================
    // --- Override WitnetRequestBoardV2Data --------------------------------------------------------------------------

    function _canDrPostBeDeletedFrom(bytes32 _drHash, address _from)
        internal view
        virtual override
        returns (bool)
    {
        WitnetV2.DrPostStatus _temporaryStatus = __drPost(_drHash).status;
        return (_temporaryStatus == WitnetV2.DrPostStatus.Rejected
            ? true
            : super._canDrPostBeDeletedFrom(_drHash, _from)
        );
    }

    function _getDrPostStatus(bytes32 _drHash)
      internal view
      virtual override
      returns (WitnetV2.DrPostStatus _temporaryStatus)
    {
      _temporaryStatus = __drPost(_drHash).status;
      if (_temporaryStatus == WitnetV2.DrPostStatus.Accepted) {
        if (block.number > _getDrPostBlock(_drHash) + __reporting().settings.acceptanceBlocks) {
            return WitnetV2.DrPostStatus.Expired;
        }
      }
      return super._getDrPostStatus(_drHash);
    }

    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      returns (bool)
    {
        return _interfaceId == type(IWitnetReporting1).interfaceId
            || _interfaceId == type(IWitnetReporting1Admin).interfaceId
            || super.supportsInterface(_interfaceId);
    }

function deleteDrPost(bytes32 _drHash)
        external
        virtual override
    {
        if (!_canDrPostBeDeletedFrom(_drHash, _msgSender())){
            revert WitnetV2.Unauthorized(_msgSender());
        }
        uint _value;
        if (__drPost(_drHash).status == WitnetV2.DrPostStatus.Posted) {
            address _reporter = __drPostRequest(_drHash).reporter;
            _value = __slashSignedUpReporter(_reporter);
            if (_value < address(this).balance) {
                revert WitnetV2.InsufficientBalance(address(this).balance, _value);
            }
        }
        __deleteDrPost(_drHash);
        if (_value > 0) {
            _safeTransferTo(payable(_msgSender()), _value);
        }
        emit DrPostDeleted(_msgSender(), _drHash);
    }
    
    // ================================================================================================================
    // --- IWitnetReporting1 implementation ---------------------------------------------------------------------------
    
    function getReportingAddressByIndex(uint _reporterIndex)
        external view
        override
        returns (address)
    {
        if (_reporterIndex >= __reporting().totalReporters) {
            revert WitnetV2.IndexOutOfBounds(_reporterIndex, __reporting().totalReporters);
        }
        return __reporting().reporters[_reporterIndex];
    }

    function getReportingAddresses()
        external view
        override
        returns (address[] memory _addrs)
    {
        _addrs = new address[](__reporting().totalReporters);
        address[] storage __addrs = __reporting().reporters;
        for (uint _ix = 0; _ix < _addrs.length; ) {
            _addrs[_ix] = __addrs[_ix];
            unchecked {
                _ix ++;
            }
        }
    }

    function getReportingSignUpConfig()
        external view
        override
        returns (SignUpConfig memory)
    {
        return __reporting().settings;
    }

    function isSignedUpReporter(address _reporter)
        public view
        virtual override
        returns (bool)
    {
        WitnetReporting1Data.Escrow storage __escrow = __reporting().escrows[_reporter];
        return (
            __escrow.weiSignUpFee > 0
                && __escrow.lastSignOutBlock > __escrow.lastSignUpBlock
        );
    }

    function totalSignedUpReporters()
        external view
        override
        returns (uint256)
    {
        return __reporting().totalReporters;
    }

    function signUp()
        external payable
        override
        nonReentrant
        returns (uint256 _index)
    {        
        IWitnetReporting1.SignUpConfig storage __settings = __reporting().settings;
        WitnetReporting1Data.Escrow storage __escrow = __reporting().escrows[_msgSender()];
        uint _fee = __settings.weiSignUpFee;
        uint _value = _getMsgValue();        
        // Check that it's not already signed up:
        if (__escrow.weiSignUpFee > 0) {
            revert IWitnetReporting1.AlreadySignedUp(_msgSender());
        }        
        // Check that it's not banned, or if so, enough blocks have elapsed since then:
        if (__escrow.lastSlashBlock > 0) {
            if (
                __settings.banningBlocks == 0 
                    || block.number < __escrow.lastSlashBlock + __settings.banningBlocks
            ) {
                revert WitnetV2.Unauthorized(_msgSender());
            }
        }        
        // Check that enough sign-up fee is being provided:        
        if (_value < _fee) {
            revert WitnetV2.InsufficientFee(_value, _fee);
        }        
        // Update storage:     
        _index = __reporting().totalReporters;
        __escrow.index = _index;
        __escrow.weiSignUpFee = _fee;
        __escrow.lastSignUpBlock = block.number;
        emit SignedUp(
            _msgSender(),
            _fee,
            __pushReporterAddress(_msgSender())
        );        
        // Transfer unused funds back:
        if (_value > _fee) {
            _safeTransferTo(payable(_msgSender()), _value - _fee);
        }
    }

    function signOut()
        external 
        override
        onlySignedUpReporters
    {
        WitnetReporting1Data.Escrow storage __escrow = __reporting().escrows[_msgSender()];   
        // Update storage:
        __escrow.lastSignOutBlock = block.number;        
        emit SigningOut(
            _msgSender(),
            __escrow.weiSignUpFee, 
            __deleteReporterAddressByIndex(__escrow.index)
        );
    }

    function acceptDrPost(bytes32 _drHash)
        external
        override
        drPostInStatus(_drHash, WitnetV2.DrPostStatus.Posted)
        onlySignedUpReporters
        onlyExpectedReporterFor(_drHash)
    {
        if (_msgSender() != __drPostRequest(_drHash).requester) {
            revert WitnetV2.Unauthorized(_msgSender());
        }
        __drPost(_drHash).status = WitnetV2.DrPostStatus.Accepted;
        emit DrPostAccepted(_msgSender(), _drHash);
    }
    
    function rejectDrPost(bytes32 _drHash, Witnet.ErrorCodes _reason)
        external payable
        override
        drPostInStatus(_drHash, WitnetV2.DrPostStatus.Posted)
        onlyExpectedReporterFor(_drHash)
        nonReentrant
    {
        uint _value = _getMsgValue();
        uint _fee = __reporting().settings.weiRejectionFee;
        // Check enough value is provided as to pay for rejection fee, if any
        if (_value < _fee) {
            revert WitnetV2.InsufficientFee(_value, _fee);
        }
        // Transfer back income funds exceeding rejection fee, if any
        if (_value > _fee) {
            _safeTransferTo(
                payable(_msgSender()),
                _value - _fee
            );
        }
        // Transfer reporter as much deposited drPost reward as possible:
        WitnetV2.DrPost storage __post = __drPost(_drHash);
        _value = __post.request.weiReward;
        if (_value > address(this).balance) {
            _value = address(this).balance;
        }
        __post.request.weiReward -= _value;
        __post.status = WitnetV2.DrPostStatus.Rejected;
        _safeTransferTo(
            payable(__post.request.requester),
            _value + _fee
        );
        emit DrPostRejected(_msgSender(), _drHash, _reason);
    }

    
}