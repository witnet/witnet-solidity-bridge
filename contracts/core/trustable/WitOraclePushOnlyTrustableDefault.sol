// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBasePushOnlyTrustable.sol";

/// @title Push-only WitOracle "trustable" contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOraclePushOnlyTrustableDefault
    is 
        WitOracleBasePushOnlyTrustable
{
    function class() virtual override public view returns (string memory) {
        return type(WitOraclePushOnlyTrustableDefault).name;
    }

    constructor(
            WitOracleRadonRegistry _registry, 
            bytes32 _versionTag
        )
        WitOracleBasePushOnly(_registry)
        WitOracleBasePushOnlyTrustable(_versionTag)
    {}
}
