// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitAppliance.sol";
import "./interfaces/IWitOracleRadonRegistry.sol";
import "./interfaces/IWitOracleRadonRegistryEvents.sol";

abstract contract WitOracleRadonRegistry
    is
        IWitAppliance,
        IWitOracleRadonRegistry,
        IWitOracleRadonRegistryEvents
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitOracleRadonRegistry).interfaceId
        );
    }
}
