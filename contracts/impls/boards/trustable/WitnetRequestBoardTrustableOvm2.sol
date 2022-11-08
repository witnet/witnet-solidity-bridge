// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBoardTrustableDefault.sol";

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
        Destructible,
        WitnetRequestBoardTrustableDefault
{  
    OVM_GasPriceOracle immutable public gasPriceOracleL1;

    constructor(
        bool _upgradable,
        bytes32 _versionTag,
        uint256 _reportResultGasLimit
    )
        WitnetRequestBoardTrustableDefault(_upgradable, _versionTag, _reportResultGasLimit)
    {
        gasPriceOracleL1 = OVM_GasPriceOracle(0x420000000000000000000000000000000000000F);
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
        return _gasPrice * _ESTIMATED_REPORT_RESULT_GAS + gasPriceOracleL1.getL1Fee(
            hex"c8f5cdd500000000000000000000000000000000000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000225820ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        );
    }
}
