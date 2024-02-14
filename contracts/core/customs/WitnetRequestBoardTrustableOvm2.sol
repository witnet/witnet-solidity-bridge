// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../defaults/WitnetRequestBoardTrustableDefault.sol";

// solhint-disable-next-line
interface OVM_GasPriceOracle {
    function getL1Fee(bytes calldata _data) external view returns (uint256);
}

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableOvm2
    is 
        WitnetRequestBoardTrustableDefault
{  
    OVM_GasPriceOracle immutable public gasPriceOracleL1;

    constructor(
            WitnetRequestFactory _factory,
            WitnetRequestBytecodes _registry,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _reportResultWithCallbackGasBase,
            uint256 _reportResultWithCallbackRevertGasBase,
            uint256 _sstoreFromZeroGas
        )
        WitnetRequestBoardTrustableDefault(
            _factory,
            _registry,
            _upgradable,
            _versionTag,
            _reportResultGasBase,
            _reportResultWithCallbackGasBase,
            _reportResultWithCallbackRevertGasBase,
            _sstoreFromZeroGas
        )
    {
        gasPriceOracleL1 = OVM_GasPriceOracle(0x420000000000000000000000000000000000000F);
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
        return WitnetRequestBoardTrustableDefault.estimateBaseFee(_gasPrice, _resultMaxSize) + (
            _gasPrice * gasPriceOracleL1.getL1Fee(
                hex"c8f5cdd500000000000000000000000000000000000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000225820ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
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
        return WitnetRequestBoardTrustableDefault.estimateBaseFeeWithCallback(
            _gasPrice, 
            _callbackGasLimit
        ) + (
            _gasPrice * gasPriceOracleL1.getL1Fee(
                hex"c8f5cdd500000000000000000000000000000000000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000225820ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
            )
        );
    }
}
