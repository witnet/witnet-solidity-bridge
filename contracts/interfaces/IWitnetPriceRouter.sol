// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./IERC165.sol";

/// @title The Witnet Price Router basic interface.
/// @dev Guides implementation of price feeds aggregation contracts.
/// @author The Witnet Foundation.
interface IWitnetPriceRouter
{
    /// Emitted everytime a price pair is attached to a new price feed contract
    /// @dev See https://github.com/adoracles/ADOIPs/blob/main/adoip-0010.md 
    /// @dev to learn how these ids are created.
    event PricePairSet(bytes32 indexed erc2362ID, IERC165 pricefeed);

    /// Returns the ERC-165-compliant price feed contract currently attending 
    /// updates on the given price pair.
    function getPriceFeed(bytes32 _erc2362id) external view returns (IERC165);

    /// Returns human-readable ERC2362-based caption of the price pair being
    /// attended by the given price feed contract address. 
    /// @dev Should fail if the given price feed contract address is not currently
    /// @dev supported by the router.
    function getPriceFeedCaption(IERC165 _priceFeed) external view returns (string memory);

    /// Helper pure function: returns hash of the provided ERC2362-compliant price pair caption.
    function hashPriceCaption(string memory _priceCaption) external pure returns (bytes32);

    /// Returns human-readable caption of the ERC2362-based price pair identifier, if known.
    function lookupERC2362ID(bytes32 _erc2362id) external view returns (string memory);

    /// Sets price feed contract attached to given price pair identifier.
    /// @dev Setting zero address to a price pair implies that it will not be attended any longer.
    /// @dev Otherwise, it should fail if the price feed contract does not support the `IWitnetPriceFeed` interface.
    function setPriceFeed(
            IERC165 _priceFeed,
            uint256 _priceDecimals,
            string calldata _priceBase,
            string calldata _priceQuote
        )
        external;

    /// Returns list of known price pairs identifiers.
    function supportedPricePairs() external view returns (bytes32[] memory);

    /// Returns `true` if given price pair is currently attached to a compliant price feed contract.
    function supportsPricePair(bytes32 _erc2362id) external view returns (bool);

    /// Returns `true` if given price feed contract is currently attached to a known price pair. 
    function supportsPriceFeed(IERC165 _priceFeed) external view returns (bool);
}
