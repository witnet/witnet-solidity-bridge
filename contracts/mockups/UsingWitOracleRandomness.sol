// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitRandomness.sol";

/// @title The UsingWitOracleRandomness contract
/// @dev Contracts willing to interact with WitRandomness appliance should just inherit from this contract.
/// @author The Witnet Foundation.
abstract contract UsingWitOracleRandomness
    is
        IWitOracleEvents,
        IWitRandomnessEvents
{
    WitOracle immutable public witnet;
    WitRandomness immutable public __RNG;

    constructor(WitRandomness _witnetRandomness) {
        require(
            address(_witnetRandomness).code.length > 0
                && _witnetRandomness.specs() == type(WitRandomness).interfaceId,
            "UsingWitOracleRandomness: uncompliant WitRandomness appliance"
        );
        __RNG = _witnetRandomness;
        witnet = __RNG.witnet();
    }

}

