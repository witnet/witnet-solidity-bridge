// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./IERC165.sol";

interface IWitnetPriceRouter
{
    event PricePairSet(bytes32 indexed erc2362ID, IERC165 pricefeed);

    function getPriceFeed(bytes32 _erc2362id) external view returns (IERC165);
    function getPriceFeedCaption(IERC165 _priceFeed) external view returns (string memory);

    function hashPriceCaption(string memory _priceCaption) external pure returns (bytes32);
    function lookupERC2362ID(bytes32 _erc2362id) external view returns (string memory);

    function setPriceFeed(
            IERC165 _priceFeed,
            uint256 _priceDecimals,
            string calldata _priceBase,
            string calldata _priceQuote
        )
        external;

    function supportedPricePairs() external view returns (bytes32[] memory);
    function supportsPricePair(bytes32 _erc2362id) external view returns (bool);
    function supportsPriceFeed(IERC165 _priceFeed) external view returns (bool);
}
