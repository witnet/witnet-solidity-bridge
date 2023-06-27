// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./customs/WitnetRequestBoardTrustableBase.sol";
import "../../patterns/Destructible.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableDefault
    is 
        Destructible,
        WitnetRequestBoardTrustableBase
{
    uint256 internal immutable _ESTIMATED_REPORT_RESULT_GAS;

    constructor(
            WitnetRequestFactory _factory,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasLimit
        )
        WitnetRequestBoardTrustableBase(
            _factory, 
            _upgradable, 
            _versionTag, 
            IERC20(address(0))
        )
    {   
        _ESTIMATED_REPORT_RESULT_GAS = _reportResultGasLimit;
    }


    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetRequestBoardView' ------------------------------------------------------

    /// Estimates the amount of reward we need to insert for a given gas price.
    /// @param _gasPrice The gas price for which we need to calculate the rewards.
    function estimateReward(uint256 _gasPrice)
        public view
        virtual override
        returns (uint256)
    {
        return _gasPrice * _ESTIMATED_REPORT_RESULT_GAS;
    }


    // ================================================================================================================
    // --- Overrides 'Destructible' -----------------------------------------------------------------------------------

    /// Destroys current instance. Only callable by the owner.
    function destruct() external override onlyOwner {
        selfdestruct(payable(msg.sender));
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
    }   
}
