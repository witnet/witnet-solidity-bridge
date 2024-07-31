// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetRadonRegistryEvents {

    /// Emitted every time a new Radon Retrieval gets successfully verified and
    /// stored in the registry.
    event NewRadonRetrieval(bytes32 hash, Witnet.RadonRetrieval retrieval);

    /// Emitted every time a new Radon Request gets successfully verified and
    /// stored in the registry.
    event NewRadonRequest(bytes32 radHash, Witnet.RadonRequest rad);
}
