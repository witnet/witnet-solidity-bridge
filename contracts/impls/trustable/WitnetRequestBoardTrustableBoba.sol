// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

// Inherits from:
import "./WitnetRequestBoardTrustableBase.sol";

// Uses:
import "../../interfaces/IERC20.sol";

/// @title Witnet Request Board OVM-compatible (Optimism) "trustable" implementation.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableBoba
    is
        Payable,
        WitnetRequestBoardTrustableBase
{
    uint256 internal lastBalance;
    uint256 internal immutable _OVM_GAS_PRICE;

    modifier ovmPayable virtual {
        _;
        // all calls to payable methods,
        // MUST update internal 'lastBalance' value at the very end.
        lastBalance = _balanceOf(address(this));
    }
            
    constructor(
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _layer2GasPrice,
            address _oETH
        )
        WitnetRequestBoardTrustableBase(_upgradable, _versionTag, _oETH)
    {
        require(address(_oETH) != address(0), "WitnetRequestBoardTrustableBoba: null currency");
        _OVM_GAS_PRICE = _layer2GasPrice;
    }

    /// Gets lastBalance of given address.
    function _balanceOf(address _from)
        internal view
        returns (uint256)
    {
        return currency.balanceOf(_from);
    }


    // ================================================================================================================
    // --- Overrides 'Payable' ----------------------------------------------------------------------------------------

    /// Gets current transaction price.
    function _getGasPrice()
        internal view
        override
        returns (uint256)
    {
        return _OVM_GAS_PRICE;
    }

    /// Calculates `msg.value` equivalent OVM_ETH value. 
    /// @dev Based on `lastBalance` value.
    function _getMsgValue()
        internal view
        override
        returns (uint256)
    {
        uint256 _newBalance = _balanceOf(address(this));
        assert(_newBalance >= lastBalance);
        return _newBalance - lastBalance;
    }

    /// Transfers oETHs to given address.
    /// @dev Updates `lastBalance` value.
    /// @param _to OVM_ETH recipient account.
    /// @param _amount Amount of oETHs to transfer.
    function _safeTransferTo(address payable _to, uint256 _amount)
        internal
        override
    {
        uint256 _lastBalance = _balanceOf(address(this));
        require(_amount <= _lastBalance, "WitnetRequestBoardTrustableBoba: insufficient funds");
        lastBalance = _lastBalance - _amount;
        currency.transfer(_to, _amount);
    }
    

    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetRequestBoardView' ------------------------------------------------------

    /// @dev Estimate the minimal amount of reward we need to insert for a given gas price.
    /// @return The minimal reward to be included for the given gas price.
    function estimateReward(uint256)
        external view
        virtual override
        returns (uint256)
    {
        return _OVM_GAS_PRICE * _ESTIMATED_REPORT_RESULT_GAS;
    }

        
    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetRequestBoardRequestor' -------------------------------------------------

    function postRequest(IWitnetRequest _request)
        public payable
        virtual override
        ovmPayable
        returns (uint256)
    {
        return WitnetRequestBoardTrustableBase.postRequest(_request);
    }

    function upgradeReward(uint256 _queryId)
        public payable
        virtual override
        ovmPayable
        inStatus(_queryId, Witnet.QueryStatus.Posted) 
    {
        WitnetRequestBoardTrustableBase.upgradeReward(_queryId);  
    }
}
