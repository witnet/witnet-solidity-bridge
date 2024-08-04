// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitOracleRequestFactoryEvents {

    /// Emitted every time a new counter-factual WitOracleRequest gets verified and built. 
    event WitOracleRequestBuilt(address request);

    /// Emitted every time a new counter-factual WitOracleRequestTemplate gets verified and built. 
    event WitOracleRequestTemplateBuilt(address template);
}
