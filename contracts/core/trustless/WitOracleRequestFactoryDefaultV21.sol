// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleRequestFactoryBase.sol";

contract WitOracleRequestFactoryDefaultV21
    is
        WitOracleRequestFactoryBase  
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleRequestFactoryDefaultV21).name;
    }

    constructor(address _witOracle)
        WitOracleRequestFactoryBase(_witOracle)
    {}
}
