// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetRandomness.sol";

/// @title The UsingWitnetRandomness contract
/// @dev Contracts willing to interact with WitnetRandomness appliance should just inherit from this contract.
/// @author The Witnet Foundation.
abstract contract UsingWitnetRandomness
    is
        IWitnetOracleEvents,
        IWitnetRandomnessEvents
{
    WitnetOracle immutable public witnet;
    WitnetRandomness immutable public __RNG;

    constructor(WitnetRandomness _witnetRandomness) {
        require(
            address(_witnetRandomness).code.length > 0
                && _witnetRandomness.specs() == type(WitnetRandomness).interfaceId,
            "UsingWitnetRandomness: uncompliant WitnetRandomness appliance"
        );
        __RNG = _witnetRandomness;
        witnet = __RNG.witnet();
    }

}

