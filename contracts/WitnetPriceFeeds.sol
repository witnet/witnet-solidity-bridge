// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "ado-contracts/contracts/interfaces/IERC2362.sol";
import "./interfaces/V2/IWitnetPriceFeeds.sol";
import "./WitnetFeeds.sol";

abstract contract WitnetPriceFeeds
    is
        IERC2362,
        IWitnetPriceFeeds,
        WitnetFeeds
{   
    constructor(WitnetRequestBoard _wrb)
        WitnetFeeds(
            _wrb,
            WitnetV2.RadonDataTypes.Integer,
            "Price-"
        )
    {}
}