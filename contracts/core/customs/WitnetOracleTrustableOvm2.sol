// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../defaults/WitnetOracleTrustableDefault.sol";

// solhint-disable-next-line
interface OVM_GasPriceOracle {
    function getL1Fee(bytes calldata _data) external view returns (uint256);
}

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetOracleTrustableOvm2
    is 
        WitnetOracleTrustableDefault
{
    using Witnet for Witnet.RadonSLA;

    function class() virtual override public view returns (string memory) {
        return type(WitnetOracleTrustableOvm2).name;
    }

    constructor(
            WitnetRadonRegistry _registry,
            WitnetRequestFactory _factory,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas
        )
        WitnetOracleTrustableDefault(
            _registry,
            _factory,
            _upgradable,
            _versionTag,
            _reportResultGasBase,
            _reportResultWithCallbackGasBase,
            _reportResultWithCallbackRevertGasBase,
            _sstoreFromZeroGas
        )
    {
        __gasPriceOracleL1 = OVM_GasPriceOracle(0x420000000000000000000000000000000000000F);
    }

    OVM_GasPriceOracle immutable internal __gasPriceOracleL1;

    function _getCurrentL1Fee(uint16 _resultMaxSize) virtual internal view returns (uint256) {
        return __gasPriceOracleL1.getL1Fee(
            abi.encodePacked(
                hex"06eb2c42000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000ffffffffff00000000000000000000000000000000000000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000ff",
                _resultMaxBuffer(_resultMaxSize)
            )
        );
    }

    function _resultMaxBuffer(uint16 _resultMaxSize) private pure returns (bytes memory) {
        unchecked {
            uint256[] memory _buffer = new uint256[](_resultMaxSize / 32);
            for (uint _ix = 0; _ix < _buffer.length; _ix ++) {
                _buffer[_ix] = type(uint256).max;
            }
            return abi.encodePacked(
                _buffer,
                uint256((1 << (_resultMaxSize % 32)) - 1)
            );
        }
    }

    // ================================================================================================================
    // --- Overrides 'IWitnetOracle' ----------------------------------------------------------------------------

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function estimateBaseFee(uint256 _gasPrice, uint16 _resultMaxSize)
        public view 
        virtual override
        returns (uint256)
    {
        return _getCurrentL1Fee(_resultMaxSize) + WitnetOracleTrustableDefault.estimateBaseFee(_gasPrice, _resultMaxSize);
    }

    /// @notice Estimate the minimum reward required for posting a data request with a callback.
    /// @param _gasPrice Expected gas price to pay upon posting the data request.
    /// @param _callbackGasLimit Maximum gas to be spent when reporting the data request result.
    function estimateBaseFeeWithCallback(uint256 _gasPrice, uint24 _callbackGasLimit)
        public view
        virtual override
        returns (uint256)
    {
        return _getCurrentL1Fee(32) + WitnetOracleTrustableDefault.estimateBaseFeeWithCallback(_gasPrice, _callbackGasLimit);
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
            _getCurrentL1Fee(_querySLA.maxTallyResultSize)
                + WitnetOracleTrustableDefault.estimateExtraFee(
                    _evmGasPrice,
                    _evmWitPrice,
                    _querySLA
                )
        );
    }

    // ================================================================================================================
    // --- Overrides 'IWitnetOracleReporter' --------------------------------------------------------------------------

    /// @notice Estimates the actual earnings (or loss), in WEI, that a reporter would get by reporting result to given query,
    /// @notice based on the gas price of the calling transaction. Data requesters should consider upgrading the reward on 
    /// @notice queries providing no actual earnings.
    function estimateReportEarnings(
            uint256[] calldata _queryIds, 
            bytes calldata _evmMsgData,
            uint256 _evmGasPrice, 
            uint256 _evmWitPrice
        )
        external view
        virtual override
        returns (uint256 _revenues, uint256 _expenses)
    {
        for (uint _ix = 0; _ix < _queryIds.length; _ix ++) {
            if (
                WitnetOracleDataLib.seekQueryStatus(_queryIds[_ix]) == Witnet.QueryStatus.Posted
            ) {
                Witnet.Request storage __request = WitnetOracleDataLib.seekQueryRequest(_queryIds[_ix]);
                if (__request.gasCallback > 0) {
                    _expenses += (
                        WitnetOracleTrustableDefault.estimateBaseFeeWithCallback(_evmGasPrice, __request.gasCallback)
                            + WitnetOracleTrustableDefault.estimateExtraFee(
                                _evmGasPrice,
                                _evmWitPrice,
                                Witnet.RadonSLA({
                                    witnessingCommitteeSize: __request.witnetSLA.witnessingCommitteeSize,
                                    witnessingReward: __request.witnetSLA.witnessingReward,
                                    maxTallyResultSize: uint16(0)
                                })
                            )
                    );
                } else {
                    _expenses += (
                        WitnetOracleTrustableDefault.estimateBaseFee(_evmGasPrice)
                            + WitnetOracleTrustableDefault.estimateExtraFee(
                                _evmGasPrice,
                                _evmWitPrice,
                                __request.witnetSLA
                            )
                    );
                }
                _expenses += __request.witnetSLA.witnessingTotalReward() * _evmWitPrice;
                _revenues += __request.evmReward;
            }
        }
        _expenses += __gasPriceOracleL1.getL1Fee(_evmMsgData);
    }
}
