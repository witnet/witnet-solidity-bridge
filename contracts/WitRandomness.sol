// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitAppliance.sol";
import "./interfaces/IWitOracleQueriableConsumer.sol";
import "./interfaces/IWitRandomness.sol";

abstract contract WitRandomness
    is
        IWitAppliance,
        IWitOracleQueriableConsumer,
        IWitRandomness
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitRandomness).interfaceId
        );
    }
}
