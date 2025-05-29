// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IWitPriceFeeds.sol";
import "../interfaces/legacy/IWitPythChainlinkAggregator.sol";

contract WitPriceFeedsChainlinkAggregator is IWitPythChainlinkAggregator {

    bytes4  immutable public override id4;
    bytes32 immutable public override priceId;
    address immutable public override pyth;
    
    constructor(address _pyth, bytes4 _id4) {
        id4 = _id4;
        priceId = IWitPriceFeeds(address(pyth)).lookupPriceFeedID(IWitPriceFeeds.ID4.wrap(id4));
        pyth = _pyth;
    }

    function getAnswer(uint256) virtual public view returns (int256) {
        return latestAnswer();
    }

    function latestAnswer() virtual public view returns (int256) {
        IWitPyth.Price memory price = IWitPyth(pyth).getPriceUnsafe(IWitPyth.ID.wrap(priceId));
        return int256(int64(price.price));
    }

    function latestRound() virtual public view returns (uint256) {
        // use timestamp as the round id
        return latestTimestamp();
    }

    function latestTimestamp() virtual public view returns (uint256) {
        IWitPyth.Price memory price = IWitPyth(pyth).getPriceUnsafe(IWitPyth.ID.wrap(priceId));
        return uint(Witnet.Timestamp.unwrap(price.publishTime));
    }


    /// ===============================================================================================================
    /// --- IWitPythChainlinkAggregator -------------------------------------------------------------------------------

    function decimals() virtual override public view returns (uint8) {
        int8 _exponent = IWitPriceFeeds(msg.sender).lookupPriceFeedExponent(IWitPriceFeeds.ID4.wrap(id4));
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
        IWitPyth.Price memory price = IWitPyth(pyth).getPriceUnsafe(IWitPyth.ID.wrap(priceId));
        return (
            _roundId,
            int(int64(price.price)),
            uint(Witnet.Timestamp.unwrap(price.publishTime)),
            uint(Witnet.Timestamp.unwrap(price.publishTime)),
            _roundId
        );
    }

    function latestRoundData()
        virtual override
        external view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        IWitPyth.Price memory price = IWitPyth(pyth).getPriceUnsafe(IWitPyth.ID.wrap(priceId));
        uint80 _roundId = uint80(Witnet.Timestamp.unwrap(price.publishTime));
        return (
            _roundId,
            int(int64(price.price)),
            uint(Witnet.Timestamp.unwrap(price.publishTime)),
            uint(Witnet.Timestamp.unwrap(price.publishTime)),
            _roundId
        );
    }

    function symbol() override public view returns (string memory) {
        return IWitPriceFeeds(address(pyth)).lookupPriceFeedCaption(IWitPriceFeeds.ID4.wrap(id4));
    }

    function version() virtual override external pure returns (uint256) {
        return 1;
    }
}
