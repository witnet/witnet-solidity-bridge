// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitAppliance.sol";
import "./interfaces/IWitOracle.sol";
import "./interfaces/IWitOracleQueriable.sol";
import "./interfaces/IWitOracleQueriableEvents.sol";

/// @title Witnet Request Board functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitOracle
    is
        IWitAppliance,
        IWitOracle,
        IWitOracleQueriable,
        IWitOracleQueriableEvents
{
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IWitOracle).interfaceId
                ^ type(IWitOracleQueriable).interfaceId
        );
    }
}
