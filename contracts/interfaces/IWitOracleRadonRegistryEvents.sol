// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRegistryEvents {

    /// Emitted every time a new Radon Reducer gets successfully verified and
    /// stored into the WitOracleRadonRegistry.
    event NewRadonReducer(bytes32 hash);

    /// Emitted every time a new Radon Retrieval gets successfully verified and
    /// stored into the WitOracleRadonRegistry.
    event NewRadonRetrieval(bytes32 hash);

    /// Emitted every time a new Radon Request gets successfully verified and
    /// stored into the WitOracleRadonRegistry.
    event NewRadonRequest(bytes32 radHash);
}
