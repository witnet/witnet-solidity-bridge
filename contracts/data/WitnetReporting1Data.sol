// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/V2/IWitnetReporting1.sol";
import "../interfaces/V2/IWitnetReporting1Admin.sol";

/// @title Witnet Request Board base data model. 
/// @author The Witnet Foundation.
abstract contract WitnetReporting1Data
    is
        IWitnetReporting1,
        IWitnetReporting1Admin
{

    bytes32 internal constant _WITNET_REPORTING_1_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data.v2.reporting.1") */
        0x32ecea6ea7fbc6d7e8c8041c5ecf898bf8d40bd92da1207bebee19461a94c7bd;

    struct Escrow {
        uint256 index;
        uint256 weiSignUpFee;
        uint256 lastSignUpBlock;
        uint256 lastSignOutBlock;
        uint256 lastSlashBlock;
    }

    struct Reporting {
        uint256 totalReporters;
        IWitnetReporting1.SignUpConfig settings;
        address[] reporters;
        mapping (address => Escrow) escrows;
    }

    // --- Internal view functions

    

    // ================================================================================================================
    // --- Internal state-modifying functions -------------------------------------------------------------------------

    function __deleteReporterAddressByIndex(uint _index)
        internal
        returns (uint256 _totalReporters)
    {
        _totalReporters = __reporting().totalReporters;
        if (_index >= _totalReporters) {
            revert WitnetV2.IndexOutOfBounds(_index, _totalReporters);
        }
        else if (_totalReporters > 1 && _index < _totalReporters - 1) {
            address _latestReporterAddress = __reporting().reporters[_totalReporters - 1];
            Escrow storage __latestReporterEscrow = __reporting().escrows[_latestReporterAddress];
            __latestReporterEscrow.index = _index;
            __reporting().reporters[_index] = _latestReporterAddress;
        }
        __reporting().reporters.pop();
        __reporting().totalReporters = -- _totalReporters;
    }
    
    function __pushReporterAddress(address _reporterAddr)
        internal
        returns (uint256 _totalReporters)
    {
        __reporting().reporters.push(_reporterAddr);
        return ++ __reporting().totalReporters;
    }

    /// @dev Returns storage pointer to contents of 'Board' struct.
    function __reporting()
      internal pure
      returns (Reporting storage _ptr)
    {
        assembly {
            _ptr.slot := _WITNET_REPORTING_1_DATA_SLOTHASH
        }
    }

    /// @dev Slash given reporter, after checking slashing conditions for sender are met.
    function __slashSignedUpReporter(address _reporter)
        internal
        virtual
        returns (uint256 _weiValue)
    {
        WitnetReporting1Data.Escrow storage __escrow = __reporting().escrows[_reporter];
        if (__escrow.weiSignUpFee > 0) {
            if (
                __escrow.lastSignOutBlock < __escrow.lastSignUpBlock
                    || block.number < __escrow.lastSignUpBlock + __reporting().settings.banningBlocks
            ) {
                _weiValue = __escrow.weiSignUpFee;
                __escrow.weiSignUpFee = 0;
                __escrow.lastSlashBlock = block.number;
                emit Slashed(
                    _reporter,
                    _weiValue,
                    __deleteReporterAddressByIndex(__escrow.index)
                );
            }
        }
    }  

}