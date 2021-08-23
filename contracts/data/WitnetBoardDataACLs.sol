// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetBoardData.sol";

/// @title Witnet Access Control Lists storage layout, for Witnet-trusted request boards.
/// @author The Witnet Foundation.
abstract contract WitnetBoardDataACLs
    is
        WitnetBoardData
{
    bytes32 internal constant _WITNET_BOARD_ACLS_SLOTHASH =
        /* keccak256("io.witnet.boards.data.acls") */
        0xa6db7263983f337bae2c9fb315730227961d1c1153ae1e10a56b5791465dd6fd;

    struct WitnetBoardACLs {
        mapping (address => bool) isReporter_;
    }

    constructor() {
        _acls().isReporter_[msg.sender] = true;
    }

    modifier onlyReporters {
        require(
            _acls().isReporter_[msg.sender],
            "WitnetBoardDataACLs: unauthorized reporter"
        );
        _;
    } 

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _acls() internal pure returns (WitnetBoardACLs storage _struct) {
        assembly {
            _struct.slot := _WITNET_BOARD_ACLS_SLOTHASH
        }
    }
}
