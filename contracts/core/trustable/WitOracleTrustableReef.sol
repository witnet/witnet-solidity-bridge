// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBaseTrustable.sol";

/// @title Witnet Request Board OVM-compatible (Optimism) "trustable" implementation.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustableReef
    is
        WitOracleBaseTrustable
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleTrustableReef).name;
    }
    
    constructor(
            EvmImmutables memory _immutables,
            WitOracleRadonRegistry _registry,
            bytes32 _versionTag
        )
        WitOracleBase(
            _immutables,
            _registry
        )
        WitOracleBaseTrustable(_versionTag)
    {}

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

    // ================================================================================================================
    // --- Overrides 'IWitOracle' ----------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function estimateBaseFee(uint256, uint16 _resultMaxSize)
        public view
        virtual override
        returns (uint256)
    {
        return WitOracleBaseTrustable.estimateBaseFee(1, _resultMaxSize);
    }

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _callbackGas Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256, uint24 _callbackGas)
        public view
        virtual override
        returns (uint256)
    {
        return WitOracleBase.estimateBaseFeeWithCallback(1, _callbackGas);
    }
}
