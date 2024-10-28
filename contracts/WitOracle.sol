// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleRadonRegistry.sol";
import "./WitOracleRequestFactory.sol";

import "./interfaces/IWitAppliance.sol";
import "./interfaces/IWitOracle.sol";
import "./interfaces/IWitOracleEvents.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitOracle
    is
        IWitAppliance,
        IWitOracle,
        IWitOracleEvents
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitAppliance).interfaceId
                ^ type(IWitOracle).interfaceId
        );
    }
}
