// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitnetRequestFactoryEvents {

    /// Emitted every time a new counter-factual WitnetRequest gets verified and built. 
    event WitnetRequestBuilt(address request);

    /// Emitted every time a new counter-factual WitnetRequestTemplate gets verified and built. 
    event WitnetRequestTemplateBuilt(address template);
}
