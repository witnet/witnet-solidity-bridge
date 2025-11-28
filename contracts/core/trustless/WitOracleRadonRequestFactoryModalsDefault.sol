// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleRadonRequestFactoryModals.sol";

/// @title Factory contract for building IWitOracleRadonRequestModal contracts as light-weight proxies.
/// @author The Witnet Foundation
contract WitOracleRadonRequestFactoryModalsDefault
    is 
        WitOracleRadonRequestFactoryModals
{
    function class() virtual override public view returns (string memory) {
        return (
            initialized() 
                ? type(IWitOracleRadonRequestModalFactory).name  
                : type(WitOracleRadonRequestFactoryModalsDefault).name
        );
    }

    constructor(address _witOracle)
        WitOracleRadonRequestFactoryModals(_witOracle)
    {}
}
