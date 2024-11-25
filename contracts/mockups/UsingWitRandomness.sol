// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitRandomness.sol";

/// @title The UsingWitRandomness contract
/// @dev Contracts willing to interact with WitRandomness appliance should just inherit from this contract.
/// @author The Witnet Foundation.
abstract contract UsingWitRandomness
    is
        IWitOracleEvents,
        IWitRandomnessEvents
{
    WitOracle public immutable witOracle;
    WitRandomness internal immutable __RNG;

    constructor(WitRandomness _witRandomness) {
        require(
            address(_witRandomness).code.length > 0
                && _witRandomness.specs() == (
                    type(IWitOracleAppliance).interfaceId
                        ^ type(IWitRandomness).interfaceId
                ),
            "UsingWitRandomness: uncompliant WitRandomness appliance"
        );
        __RNG = _witRandomness;
        witOracle = __RNG.witOracle();
    }

    /// @dev As to accept transfers back from the `WitRandomness` appliance
    /// @dev when excessive fee is passed over to the `__RNG.randomize()` method. 
    receive() external payable virtual {}

}

