// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IWitnetPriceRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IWitnetPriceFeed.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WitnetPriceRouter
    is
        IWitnetPriceRouter,
        Ownable
{
    using Strings for uint256;
    
    struct Pair {
        IERC165 pricefeed;
        uint256 decimals;
        string  base;
        string  quote;
    }    

    mapping (bytes4 => Pair) internal __pairs;
    mapping (address => bytes32) internal __pricefeedId_;

    bytes32[] internal __supportedCurrencyPairs;

    // ========================================================================
    // --- Implementation of 'IERC2362' ---------------------------------------

    /// Returns last valid price value and timestamp, as well as status of
    /// the latest update request that got posted to the Witnet Request Board. 
    /// @dev Fails if the given currency pair is not currently supported.
    /// @param _erc2362id Price pair identifier as specified in https://github.com/adoracles/ADOIPs/blob/main/adoip-0010.md
    /// @return _lastPrice Last valid price reported back from the Witnet oracle.
    /// @return _lastTimestamp EVM-timestamp of the last valid price.
    /// @return _latestUpdateStatus Status code of latest update request that got posted to the Witnet Request Board:
    ///          - 200: latest update request was succesfully solved with no errors
    ///          - 400: latest update request was solved with errors
    ///          - 404: latest update request is still pending to be solved    
	function valueFor(bytes32 _erc2362id)
        external view
        virtual override
        returns (
            int256 _lastPrice,
            uint256 _lastTimestamp,
            uint256 _latestUpdateStatus
        )
    {
        IWitnetPriceFeed _pricefeed = IWitnetPriceFeed(address(getPriceFeed(_erc2362id)));
        require(address(_pricefeed) != address(0), "WitnetPriceRouter: unsupported currency pair");
        (_lastPrice, _lastTimestamp,, _latestUpdateStatus) = _pricefeed.lastValue();
    }


    // ========================================================================
    // --- Implementation of 'IWitnetPriceRouter' ---------------------------    

    /// Helper pure function: returns hash of the provided ERC2362-compliant currency pair caption (aka ID).
    function currencyPairId(string memory _caption)
        public pure
        virtual override
        returns (bytes32)
    {
        return keccak256(bytes(_caption));
    }

    /// Returns the ERC-165-compliant price feed contract currently serving 
    /// updates on the given currency pair.
    function getPriceFeed(bytes32 _erc2362id)
        public view
        virtual override
        returns (IERC165)
    {
        return __pairs[bytes4(_erc2362id)].pricefeed;
    }

    /// Returns human-readable ERC2362-based caption of the currency pair being
    /// served by the given price feed contract address. 
    /// @dev Fails if the given price feed contract address is not currently
    /// @dev registered in the router.
    function getPriceFeedCaption(IERC165 _pricefeed) 
        public view
        virtual override
        returns (string memory)
    {
        require(supportsPriceFeed(_pricefeed), "WitnetPriceRouter: unknown");
        return lookupERC2362ID(__pricefeedId_[address(_pricefeed)]);
    }

    /// Returns human-readable caption of the ERC2362-based currency pair identifier, if known.
    function lookupERC2362ID(bytes32 _erc2362id)
        public view
        virtual override
        returns (string memory _caption)
    {
        Pair storage _pair = __pairs[bytes4(_erc2362id)];
        if (
            bytes(_pair.base).length > 0 
                && bytes(_pair.quote).length > 0
        ) {
            _caption = string(abi.encodePacked(
                "Price-",
                _pair.base,
                "/",
                _pair.quote,
                "-",
                _pair.decimals.toString()
            ));
        }
    }

    /// Register a price feed contract that will serve updates for the given currency pair.
    /// @dev Setting zero address to a currency pair implies that it will not be served any longer.
    /// @dev Otherwise, fails if the price feed contract does not support the `IWitnetPriceFeed` interface,
    /// @dev or if given price feed is already serving another currency pair (within this WitnetPriceRouter instance).
    function setPriceFeed(
            IERC165 _pricefeed,
            uint256 _decimals,
            string calldata _base,
            string calldata _quote
        )
        public 
        virtual override
        onlyOwner
    {
        if (address(_pricefeed) != address(0)) {
            require(
                _pricefeed.supportsInterface(type(IWitnetPriceFeed).interfaceId),
                "WitnetPriceRouter: feed contract is not compliant with IWitnetPriceFeed"
            );
            require(
                __pricefeedId_[address(_pricefeed)] == bytes32(0),
                "WitnetPriceRouter: already serving a currency pair"
            );
        }
        bytes memory _caption = abi.encodePacked(
            "Price-",
            bytes(_base),
            "/",
            bytes(_quote),
            "-",
            _decimals.toString()
        );
        bytes32 _erc2362id = keccak256(_caption);
        
        Pair storage _record = __pairs[bytes4(_erc2362id)];
        address _currentPriceFeed = address(_record.pricefeed);
        if (bytes(_record.base).length == 0) {
            _record.base = _base;
            _record.quote = _quote;
            _record.decimals = _decimals;
            __supportedCurrencyPairs.push(_erc2362id);
        }
        else if (_currentPriceFeed != address(0)) {
            __pricefeedId_[_currentPriceFeed] = bytes32(0);
        }
        if (address(_pricefeed) != _currentPriceFeed) {
            __pricefeedId_[address(_pricefeed)] = _erc2362id;
        }
        _record.pricefeed = _pricefeed;
        emit CurrencyPairSet(_erc2362id, _pricefeed);
    }

    /// Returns list of known currency pairs IDs.
    function supportedCurrencyPairs()
        external view
        virtual override
        returns (bytes32[] memory)
    {
        return __supportedCurrencyPairs;
    }

    /// Returns `true` if given pair is currently being served by a compliant price feed contract.
    function supportsCurrencyPair(bytes32 _erc2362id)
        public view
        virtual override
        returns (bool)
    {
        return address(__pairs[bytes4(_erc2362id)].pricefeed) != address(0);
    }

    /// Returns `true` if given price feed contract is currently serving updates to any known currency pair. 
    function supportsPriceFeed(IERC165 _pricefeed)
        public view
        virtual override
        returns (bool)
    {
        return __pairs[bytes4(__pricefeedId_[address(_pricefeed)])].pricefeed == _pricefeed;
    }
}
