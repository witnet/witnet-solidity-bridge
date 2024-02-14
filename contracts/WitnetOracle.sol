// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBytecodes.sol";
import "./WitnetRequestFactory.sol";
import "./interfaces/V2/IWitnetOracle.sol";
import "./interfaces/V2/IWitnetOracleEvents.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetOracle
    is
        IWitnetOracle,
        IWitnetOracleEvents
{
    function class() virtual external view returns (string memory) {
        return type(WitnetOracle).name;
    }
    function channel() virtual external view returns (bytes4);
    function factory() virtual external view returns (WitnetRequestFactory);
    function registry() virtual external view returns (WitnetRequestBytecodes);
    function specs() virtual external view returns (bytes4);
}