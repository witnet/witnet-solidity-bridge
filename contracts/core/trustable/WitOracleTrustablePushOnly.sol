// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../base/WitOracleBasePushOnlyTrustable.sol";

/// @title Witnet Request Board "trustable" implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleTrustablePushOnly
    is 
        WitOracleBasePushOnlyTrustable
{
    function class() virtual override public view returns (string memory) {
        return type(WitOracleTrustablePushOnly).name;
    }

    constructor(bytes32 _versionTag)
        WitOracleBasePushOnlyTrustable(_versionTag)
    {}
}
