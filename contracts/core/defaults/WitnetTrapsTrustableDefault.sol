// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetTrapsTrustableBase.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetTrapsTrustableDefault
    is 
        WitnetTrapsTrustableBase
{
    using WitnetV2 for WitnetV2.Request;
    
    uint256 internal immutable __reportResultGasBase;
    uint256 internal immutable __sstoreFromZeroGas;

    constructor(
            WitnetBytecodes _registry,
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _reportResultGasBase,
            uint256 _sstoreFromZeroGas
        )
        WitnetTrapsTrustableBase(
            _registry,
            _upgradable, 
            _versionTag
        )
    {   
        __reportResultGasBase = _reportResultGasBase;
        __sstoreFromZeroGas = _sstoreFromZeroGas;
    }


    // ================================================================================================================
    // --- Overrides 'WitnetTrapsTrustableBase' -----------------------------------------------------------------------

    function _blockNumber()
        virtual override
        internal view 
        returns (uint64)
    {
        return uint64(block.number);
    }

    function _blockTimestamp()
        virtual override
        internal view 
        returns (uint64)
    {
        return uint64(block.timestamp);
    }

    function _hashTrapReport(TrapReport calldata report)
        virtual override
        internal pure 
        returns (bytes16)
    {
        return bytes16(keccak256(abi.encode(
            report.drRadHash,
            report.drTimestamp,
            report.drWitnesses,
            report.drTallyCborBytes
        )));
    }


    // ================================================================================================================
    // --- Overrides 'IWitnetTraps' -----------------------------------------------------------------------------------

    function estimateBaseFee(uint256 gasPrice, uint16 maxResultSize)
        virtual override
        public view
        returns (uint256)
    {
        return gasPrice * (
            __reportResultGasBase
                + __sstoreFromZeroGas * (
                    5 + (maxResultSize == 0 ? 0 : maxResultSize - 1) / 32
                )
        );
    }

}
   