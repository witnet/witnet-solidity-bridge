// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "ado-contracts/contracts/interfaces/IERC2362.sol";
import "./interfaces/V2/IWitnetPriceFeeds.sol";
import "./interfaces/V2/IWitnetPriceSolverDeployer.sol";
import "./WitnetFeeds.sol";

abstract contract WitnetPriceFeeds
    is
        IERC2362,
        IWitnetPriceFeeds,
        IWitnetPriceSolverDeployer,
        WitnetFeeds
{   
    constructor(WitnetRequestBoard _wrb)
        WitnetFeeds(
            _wrb,
            Witnet.RadonDataTypes.Integer,
            "Price-"
        )
    {}
}