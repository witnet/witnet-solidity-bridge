// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitRandomness.sol";

/// @title The UsingWitRandomness contract
/// @dev Contracts willing to interact with WitRandomness appliance should just inherit from this contract.
/// @author The Witnet Foundation.
abstract contract UsingWitRandomness
    is
        IWitOracleEvents,
        IWitRandomnessEvents
{
    WitRandomness immutable public witRandomness;

    constructor(WitRandomness _witRandomness) {
        require(
            address(_witRandomness).code.length > 0
                && _witRandomness.specs() == type(WitRandomness).interfaceId,
            "UsingWitRandomness: uncompliant WitRandomness appliance"
        );
        witRandomness = _witRandomness;
    }

    receive() external payable virtual {}

}

