// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IWitFeeds.sol";
import "./interfaces/IWitFeedsEvents.sol";
import "./interfaces/IWitOracleAppliance.sol";

import "ado-contracts/contracts/interfaces/IERC2362.sol";

abstract contract WitFeeds
    is 
        IERC2362,
        IWitFeeds,
        IWitFeedsEvents,
        IWitOracleAppliance,
        IWitOracleEvents
{
    Witnet.RadonDataTypes immutable public override dataType;
    bytes32 immutable internal __prefix;

    constructor(
            Witnet.RadonDataTypes _dataType,
            string memory _prefix
        )
    {
        dataType = _dataType;
        __prefix = Witnet.toBytes32(bytes(_prefix));
    }

    function prefix() override public view returns (string memory) {
        return Witnet.toString(__prefix);
    }
}
