// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../trustable/WitnetRequestBoardV03.sol";

/**
 * @title Witnet Requests Board latest implementation, to be used as primary reference and main testing target.
 * @notice Contract to bridge requests to Witnet Decenetralized Oracle Network.
 * @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
 * The result of the requests will be posted back to this contract by the bridge nodes too.
 * @author Witnet Foundation
 **/
contract WitnetRequestBoardLatest is WitnetRequestBoardV03 {
    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetRequestBoardV03(_upgradable, _versionTag)
    {
    }
}
