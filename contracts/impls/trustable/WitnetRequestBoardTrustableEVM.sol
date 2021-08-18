// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBoardTrustableBase.sol";
import "../../patterns/Destructible.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableEVM
    is 
        Destructible,
        WitnetRequestBoardTrustableBase
{  
    constructor(bool _upgradable, bytes32 _versionTag)
        WitnetRequestBoardTrustableBase(_upgradable, _versionTag, address(0))
    {}


    // ================================================================================================================
    // --- Overrides 'Destructible' -----------------------------------------------------------------------------------

    /// Destroys current instance. Only callable by the owner.
    function destroy() external override onlyOwner {
        selfdestruct(payable(msg.sender));
    }


    // ================================================================================================================
    // --- Overrides 'Payable' ----------------------------------------------------------------------------------------

    /// Gets balance of given address.
    function balanceOf(address _from)
        public view
        override
        returns (uint256)
    {
        return _from.balance;
    }

    /// Gets current transaction price.
    function _getGasPrice()
        internal view
        override
        returns (uint256)
    {
        return tx.gasprice;
    }

    /// Gets current payment value.
    function _getMsgValue()
        internal view
        override
        returns (uint256)
    {
        return msg.value;
    }

    /// Transfers ETHs to given address.
    /// @param _to Recipient address.
    /// @param _amount Amount of ETHs to transfer.
    function _safeTransferTo(address payable _to, uint256 _amount)
        internal
        override
    {
        payable(_to).transfer(_amount);
    }   
}
