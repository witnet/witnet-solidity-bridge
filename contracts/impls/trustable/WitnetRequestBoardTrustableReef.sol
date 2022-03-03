// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

// Inherits from:
import "./WitnetRequestBoardTrustableDefault.sol";

/// @title Witnet Request Board OVM-compatible (Optimism) "trustable" implementation.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableReef
    is
        WitnetRequestBoardTrustableDefault
{           
    constructor(
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasLimit
        )
        WitnetRequestBoardTrustableDefault(_upgradable, _versionTag, _reportResultGasLimit)
    {}
    
    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetRequestBoardView' ------------------------------------------------------

    /// @dev Estimate the minimal amount of reward we need to insert for a given gas price.
    /// @return The minimal reward to be included for the given gas price.
    function estimateReward(uint256)
        public view
        virtual override
        returns (uint256)
    {
        return _ESTIMATED_REPORT_RESULT_GAS;
    }

    // ================================================================================================================
    // --- Overrides 'Payable' ----------------------------------------------------------------------------------------

    /// Gets current transaction price.
    function _getGasPrice()
        internal pure
        virtual override
        returns (uint256)
    {
        return 1;
    }
}
