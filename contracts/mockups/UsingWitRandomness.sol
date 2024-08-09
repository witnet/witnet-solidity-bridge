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
    WitRandomness immutable public witOracleRandomness;

    constructor(WitRandomness _witOracleRandomness) {
        require(
            address(_witOracleRandomness).code.length > 0
                && _witOracleRandomness.specs() == type(WitRandomness).interfaceId,
            "UsingWitRandomness: uncompliant WitRandomness appliance"
        );
        witOracleRandomness = _witOracleRandomness;
    }

    receive() external payable virtual {}

}

