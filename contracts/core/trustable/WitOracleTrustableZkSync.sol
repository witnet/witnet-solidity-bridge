// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseQueriableTrustable.sol";

/// @title Queriable WitOracle "trustable" implementation for zkSync-Era chains.
/// @author The Witnet Foundation
contract WitOracleTrustableZkSync
    is
        WitOracleBaseQueriableTrustable
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleTrustableZkSync).name;
    }

    uint256 internal immutable __reportResultGasPerPubData = 50000;
    
    constructor(WitOracleRadonRegistry _registry)
        WitOracleBaseQueriable(
            EvmImmutables({
                reportResultGasBase: 50000,
                reportResultWithCallbackGasBase: 60000,
                reportResultWithCallbackRevertGasBase: 70000, 
                sstoreFromZeroGas: 22100
            }),
            _registry
        )
        WitOracleBaseQueriableTrustable("zksync-experimental")
    {}

    
    // ================================================================================================================
    // --- Overrides 'Payable' ----------------------------------------------------------------------------------------

    /// Transfers ETHs to given address.
    /// @param _to Recipient address.
    /// @param _amount Amount of ETHs to transfer.
    function __safeTransferTo(address payable _to, uint256 _amount) virtual override internal {
        (bool _success,) = payable(_to).call{value: _amount}("");
        if (!_success) revert("cannot transfer back");
    }
    

    // ================================================================================================================
    // --- Overrides 'IWitOracle' ----------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @param _evmGasPrice Expected gas price to pay upon posting the data request.
    function estimateBaseFee(uint256 _evmGasPrice)
        public view
        virtual override
        returns (uint256)
    {
        return (
            WitOracleBaseQueriable.estimateBaseFee(_evmGasPrice) + (
                _evmGasPrice
                    * __reportResultGasPerPubData * (
                        4    // heuristic: 1x contracts storage roots get modified
                        + 8  // heuristic: 1x evm events get emitted
                    )
            )
        );
    }

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _callbackGas Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _evmGasPrice, uint24 _callbackGas)
        public view
        virtual override
        returns (uint256)
    {
        return (
            WitOracleBaseQueriable.estimateBaseFeeWithCallback(_evmGasPrice, _callbackGas) + (
                _evmGasPrice
                    * __reportResultGasPerPubData * (
                        8   // heuristic: 2x contracts storage roots get modified
                        + 8  // heuristic: 1x evm events get emitted
                    )
            )
        );
    }
}
