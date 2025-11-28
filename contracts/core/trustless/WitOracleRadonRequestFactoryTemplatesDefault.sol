// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleRadonRequestFactoryTemplates.sol";

/// @title Factory contract for building IWitOracleRadonRequestTemplate contracts as light-weight proxies.
/// @author The Witnet Foundation
contract WitOracleRadonRequestFactoryTemplatesDefault
    is 
        WitOracleRadonRequestFactoryTemplates
{
    function class() virtual override public view  returns (string memory) {
        return (
            initialized() 
                ? type(IWitOracleRadonRequestTemplateFactory).name  
                : type(WitOracleRadonRequestFactoryTemplatesDefault).name
        );
    }

    constructor(address _witOracle)
        WitOracleRadonRequestFactoryTemplates(_witOracle)
    {}
}
