// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IWitPriceFeeds.sol";
import "../interfaces/legacy/IWitPythChainlinkAggregator.sol";

contract WitPriceFeedsChainlinkAggregator is IWitPythChainlinkAggregator {

    bytes4 immutable public override id4;
    IWitPyth immutable public override pyth;
    
    constructor(IWitPyth _pyth, IWitPriceFeeds.ID4 _id4) {
        id4 = IWitPriceFeeds.ID4.unwrap(_id4);
        pyth = _pyth;
    }

    function decimals() override public view returns (uint8) {
        int8 _exponent = IWitPriceFeeds(msg.sender).lookupPriceFeed(IWitPriceFeeds.ID4.wrap(id4)).exponent;
        return (_exponent < 0 ? uint8(-_exponent) : uint8(_exponent));
    }

    function description() override external view returns (string memory) {
        return symbol();
    }

    function getRoundData(uint80 _roundId)
        override external view 
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        // TODO
    }

    function latestRoundData()
        override external view 
        returns (
            uint80,
            int256, 
            uint256,
            uint256,
            uint80
        )
    {
        // TODO
    }

    function priceId() override public view returns (IWitPyth.ID) {
        return IWitPriceFeeds(address(pyth)).lookupPriceFeed(IWitPriceFeeds.ID4.wrap(id4)).id;
    }

    function symbol() override public view returns (string memory) {
        return IWitPriceFeeds(address(pyth)).lookupSymbol(IWitPriceFeeds.ID4.wrap(id4));
    }
}