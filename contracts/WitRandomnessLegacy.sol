// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleQueriableEvents.sol";
import "./interfaces/legacy/IWitRandomnessLegacy.sol";

abstract contract WitRandomnessLegacy
    is
        IWitOracleAppliance,
        IWitOracleQueriableEvents,
        IWitRandomnessLegacy
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitRandomnessLegacy).interfaceId
        );
    }
}
