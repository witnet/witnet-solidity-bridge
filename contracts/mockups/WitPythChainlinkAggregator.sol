// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IWitPriceFeeds, IWitPriceFeedsTypes} from "../interfaces/IWitPriceFeeds.sol";
import {IWitPythChainlinkAggregator} from "../interfaces/legacy/IWitPythChainlinkAggregator.sol";
import {Witnet} from "../libs/Witnet.sol";

contract WitPythChainlinkAggregator
    is
        IWitPythChainlinkAggregator, 
        IWitPriceFeedsTypes
{
    bytes4  immutable public override id4;
    bytes32 immutable public override priceId;
    address immutable public override pyth;
    address immutable public override witOracle;
    
    constructor(address _witOracle, bytes4 _id4) {
        id4 = _id4;
        priceId = IWitPriceFeeds(address(_witOracle)).lookupPriceFeedID32(ID4.wrap(id4));
        pyth = _witOracle;
        witOracle = _witOracle;
    }

    function getAnswer(uint256) virtual public view returns (int256) {
        return latestAnswer();
    }

    function latestAnswer() virtual public view returns (int256) {
        IWitPriceFeeds.Price memory price = IWitPriceFeeds(witOracle).getPriceUnsafe(ID4.wrap(id4));
        return int256(int64(price.price));
    }

    function latestRound() virtual public view returns (uint256) {
        // use timestamp as the round id
        return latestTimestamp();
    }

    function latestTimestamp() virtual public view returns (uint256) {
        IWitPriceFeeds.Price memory price = IWitPriceFeeds(witOracle).getPriceUnsafe(ID4.wrap(id4));
        return uint(Witnet.Timestamp.unwrap(price.timestamp));
    }


    /// ===============================================================================================================
    /// --- IWitPythChainlinkAggregator -------------------------------------------------------------------------------

    function decimals() virtual override public view returns (uint8) {
        int8 _exponent = IWitPriceFeeds(msg.sender).lookupPriceFeedExponent(ID4.wrap(id4));
        return (_exponent < 0 ? uint8(-_exponent) : uint8(_exponent));
    }

    function description() virtual override external view returns (string memory) {
        return symbol();
    }

    function getRoundData(uint80 _roundId) 
        virtual override 
        external view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        IWitPriceFeeds.Price memory price = IWitPriceFeeds(witOracle).getPriceUnsafe(ID4.wrap(id4));
        uint _timestamp = uint(Witnet.Timestamp.unwrap(price.timestamp));
        return (
            _roundId,
            int(int64(price.price)),
            _timestamp,
            _timestamp,
            _roundId
        );
    }

    function latestRoundData()
        virtual override
        external view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        IWitPriceFeeds.Price memory price = IWitPriceFeeds(witOracle).getPriceUnsafe(ID4.wrap(id4));
        uint80 _roundId = uint80(Witnet.Timestamp.unwrap(price.timestamp));
        uint _timestamp = uint(Witnet.Timestamp.unwrap(price.timestamp));
        return (
            _roundId,
            int(int64(price.price)),
            _timestamp,
            _timestamp,
            _roundId
        );
    }

    function symbol() override public view returns (string memory) {
        return IWitPriceFeeds(address(witOracle)).lookupPriceFeedCaption(ID4.wrap(id4));
    }

    function version() virtual override external pure returns (uint256) {
        return 3;
    }
}
