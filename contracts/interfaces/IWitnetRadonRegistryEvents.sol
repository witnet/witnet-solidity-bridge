// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetRadonRegistryEvents {

    /// Emitted every time a new Radon Reducer gets successfully verified and
    /// stored into the WitnetRadonRegistry.
    event NewRadonReducer(bytes16 hash);

    /// Emitted every time a new Radon Retrieval gets successfully verified and
    /// stored into the WitnetRadonRegistry.
    event NewRadonRetrieval(bytes32 hash);

    /// Emitted every time a new Radon Request gets successfully verified and
    /// stored into the WitnetRadonRegistry.
    event NewRadonRequest(bytes32 radHash);
}
