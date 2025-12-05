// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleRadonRegistryEvents.sol";
import "./interfaces/IWitOracleRadonRequestFactory.sol";

abstract contract WitOracleRadonRequestFactory
    is
        IWitOracleAppliance, 
        IWitOracleRadonRegistryEvents,
        IWitOracleRadonRequestFactory
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitOracleRadonRequestFactory).interfaceId
        );
    }
}
