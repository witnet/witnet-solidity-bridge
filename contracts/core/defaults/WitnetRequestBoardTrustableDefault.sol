// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBoardTrustableBase.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableDefault
    is 
        WitnetRequestBoardTrustableBase
{
    using WitnetV2 for WitnetV2.Request;
    
    uint256 internal immutable __reportResultGasBase;
    uint256 internal immutable __reportResultWithCallbackGasBase;
    uint256 internal immutable __reportResultWithCallbackRevertGasBase;
    uint256 internal immutable __sstoreFromZeroGas;

    constructor(
            WitnetRequestFactory _factory,
            WitnetBytecodes _registry,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas
        )
        WitnetRequestBoardTrustableBase(
            _factory, 
            _registry,
            _upgradable, 
            _versionTag, 
            address(0)
        )
    {   
        __reportResultGasBase = _reportResultGasBase;
        __reportResultWithCallbackGasBase = _reportResultWithCallbackGasBase;
        __reportResultWithCallbackRevertGasBase = _reportResultWithCallbackRevertGasBase;
        __sstoreFromZeroGas = _sstoreFromZeroGas;
    }


    // ================================================================================================================
    // --- Overrides 'IWitnetRequestBoard' ----------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function estimateBaseFee(uint256 _gasPrice, uint16 _resultMaxSize)
        public view
        virtual override
        returns (uint256)
    {
        return _gasPrice * (
            __reportResultGasBase
                + __sstoreFromZeroGas * (
                    5 + (_resultMaxSize == 0 ? 0 : _resultMaxSize - 1) / 32
                )
        );
    }

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _gasPrice, uint96 _callbackGasLimit)
        public view
        virtual override
        returns (uint256)
    {
        uint _reportResultWithCallbackGasThreshold = (
            __reportResultWithCallbackRevertGasBase
                + 3 * __sstoreFromZeroGas
        );
        if (
            _callbackGasLimit < _reportResultWithCallbackGasThreshold
                || __reportResultWithCallbackGasBase + _callbackGasLimit < _reportResultWithCallbackGasThreshold
        ) {
            return (
                _gasPrice
                    * _reportResultWithCallbackGasThreshold
            );
        } else {
            return (
                _gasPrice 
                    * (
                        __reportResultWithCallbackGasBase
                            + _callbackGasLimit
                    )
            );
        }
    }

    /// @notice Estimates the actual earnings (or loss), in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    /// @dev Fails if the query does not exist, or if deleted.
    function estimateQueryEarnings(uint256[] calldata _witnetQueryIds, uint256 _gasPrice)
        virtual override
        external view
        returns (int256 _earnings)
    {
        uint256 _expenses; uint256 _revenues;
        for (uint _ix = 0; _ix < _witnetQueryIds.length; _ix ++) {
            if (_statusOf(_witnetQueryIds[_ix]) == WitnetV2.QueryStatus.Posted) {
                WitnetV2.Request storage __request = __seekQueryRequest(_witnetQueryIds[_ix]);
                _revenues += __request.evmReward;
                uint96 _callbackGasLimit = __request.unpackCallbackGasLimit();
                if (_callbackGasLimit > 0) {
                    _expenses += estimateBaseFeeWithCallback(_gasPrice, _callbackGasLimit);
                } else {
                    _expenses += estimateBaseFee(
                        _gasPrice,
                        registry.lookupRadonRequestResultMaxSize(__request.RAD)
                    );
                }
            }
        }
        return int256(_revenues) - int256(_expenses);
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
