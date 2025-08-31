// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitOracleAppliance.sol";
import "./interfaces/IWitOracleQueriableEvents.sol";
import "./interfaces/IWitRandomnessV2.sol";

abstract contract WitRandomnessLegacyV2
    is
        IWitOracleAppliance,
        IWitOracleQueriableEvents,
        IWitRandomnessV2
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitRandomnessV2).interfaceId
        );
    }
}
