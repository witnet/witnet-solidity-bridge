// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleTrustableBase.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustableDefault
    is 
        WitOracleTrustableBase
{
    using Witnet for Witnet.RadonSLA;

    function class() virtual override public view returns (string memory) {
        return type(WitOracleTrustableDefault).name;
    }

    uint256 internal immutable __reportResultGasBase;
    uint256 internal immutable __reportResultWithCallbackGasBase;
    uint256 internal immutable __reportResultWithCallbackRevertGasBase;
    uint256 internal immutable __sstoreFromZeroGas;

    constructor(
            WitOracleRadonRegistry _registry,
            WitOracleRequestFactory _factory,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas
        )
        WitOracleTrustableBase(
            _registry,
            _factory,
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
    // --- Overrides 'IWitOracle' ----------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    function estimateBaseFee(uint256 _gasPrice)
        public view
        virtual override
        returns (uint256)
    {
        return _gasPrice * (
            __reportResultGasBase 
                + 4 * __sstoreFromZeroGas
        );
    }

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _gasPrice, uint24 _callbackGasLimit)
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

    /// @notice Estimate the extra reward (i.e. over the base fee) to be paid when posting a new
    /// @notice data query in order to avoid getting provable "too low incentives" results from
    /// @notice the Wit/oracle blockchain. 
    /// @dev The extra fee gets calculated in proportion to:
    /// @param _evmGasPrice Tentative EVM gas price at the moment the query result is ready.
    /// @param _evmWitPrice Tentative nanoWit price in Wei at the moment the query is solved on the Wit/oracle blockchain.
    /// @param _querySLA The query SLA data security parameters as required for the Wit/oracle blockchain. 
    function estimateExtraFee(
            uint256 _evmGasPrice, 
            uint256 _evmWitPrice, 
            Witnet.RadonSLA memory _querySLA
        )
        public view
        virtual override
        returns (uint256)
    {
        return (
            _evmWitPrice * ((3 + _querySLA.witNumWitnesses) * _querySLA.witUnitaryReward)
                + (_querySLA.maxTallyResultSize > 32
                    ? _evmGasPrice * __sstoreFromZeroGas * ((_querySLA.maxTallyResultSize - 32) / 32)
                    : 0
                )
        );
    }


    /// ===============================================================================================================
    /// --- IWitOracleLegacy ---------------------------------------------------------------------------------------

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
                    4 + (_resultMaxSize == 0 ? 0 : _resultMaxSize - 1) / 32
                )
        );
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
