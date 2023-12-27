// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetBytecodes.sol";
import "./interfaces/V2/IWitnetTraps.sol";
import "./interfaces/V2/IWitnetTrapsEvents.sol";

/// @title WitnetTraps: Witnet Push Oracle base contract
/// @author The Witnet Foundation.
abstract contract WitnetTraps
    is
        IWitnetTraps,
        IWitnetTrapsEvents
{
    function class() virtual external view returns (string memory) {
        return type(WitnetTraps).name;
    }
    function registry() virtual external view returns (WitnetBytecodes);
    function specs() virtual external view returns (bytes4);
}
