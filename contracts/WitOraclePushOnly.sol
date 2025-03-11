// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitAppliance.sol";
import "./interfaces/IWitOracle.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitOraclePushOnly
    is
        IWitAppliance,
        IWitOracle
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitAppliance).interfaceId
                ^ type(IWitOracle).interfaceId
        );
    }
}
