// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IWitnetPriceRouter.sol";
import "ado-contracts/contracts/interfaces/IERC2362.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IWitnetPriceFeed.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WitnetPriceRouter
    is
        IERC2362,
        IWitnetPriceRouter,
        Ownable
{
    using Strings for uint256;
    
    struct PricePair {
        IERC165 feed;
        uint256 decimals;
        string  base;
        string  quote;
    }    

    mapping (bytes32 => PricePair) internal __pairs;
    mapping (address => bytes32) internal __feedId_;

    bytes32[] internal __supportedPricePairs;

    // ========================================================================
    // --- Implementation of 'IERC2362' ---------------------------------------

    /// Returns last valid price value and timestamp, as well as status of
    /// the latest update request that got posted to the Witnet Request Board. 
    /// @dev Fails if the given price pair is not currently supported.
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
        IWitnetPriceFeed _feed = IWitnetPriceFeed(address(getPriceFeed(_erc2362id)));
        require(address(_feed) != address(0), "WitnetPriceRouter: not currently supported");
        return _feed.lastValue();
    }


    // ========================================================================
    // --- Implementation of 'IWitnetPriceRouter' ---------------------------    

    /// Returns the ERC-165-compliant price feed contract currently attending 
    /// updates on the given price pair.
    function getPriceFeed(bytes32 _erc2362id)
        public view
        virtual override
        returns (IERC165)
    {
        return __pairs[_erc2362id].feed;
    }

    /// Returns human-readable ERC2362-based caption of the price pair being
    /// attended by the given price feed contract address. 
    /// @dev Fails if the given price feed contract address is not currently
    /// @dev supported by the router.
    function getPriceFeedCaption(IERC165 _feed) 
        public view
        virtual override
        returns (string memory)
    {
        require(supportsPriceFeed(_feed), "WitnetPriceRouter: unknown");
        return lookupERC2362ID(__feedId_[address(_feed)]);
    }

    /// Helper pure function: returns hash of the provided ERC2362-compliant price pair caption.
    function hashPriceCaption(string memory _caption)
        public pure
        virtual override
        returns (bytes32)
    {
        return keccak256(bytes(_caption));
    }

    /// Returns human-readable caption of the ERC2362-based price pair identifier, if known.
    function lookupERC2362ID(bytes32 _erc2362id)
        public view
        virtual override
        returns (string memory _caption)
    {
        PricePair storage _pair = __pairs[_erc2362id];
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

    /// Sets price feed contract attached to given price pair identifier.
    /// @dev Setting zero address to a price pair implies that it will not be attended any longer.
    /// @dev Otherwise, fails if the price feed contract does not support the `IWitnetPriceFeed` interface.
    function setPriceFeed(
            IERC165 _feed,
            uint256 _decimals,
            string calldata _base,
            string calldata _quote
        )
        public 
        virtual override
        onlyOwner
    {
        if (address(_feed) != address(0)) {
            require(
                _feed.supportsInterface(type(IWitnetPriceFeed).interfaceId),
                "WitnetPriceRouter: non-compliant"
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
        PricePair storage _record = __pairs[_erc2362id];
        address _currentFeed = address(_record.feed);
        if (bytes(_record.base).length == 0) {
            _record.base = _base;
            _record.quote = _quote;
            _record.decimals = _decimals;
            __supportedPricePairs.push(_erc2362id);
        }
        else if (_currentFeed != address(0)) {
            __feedId_[_currentFeed] = bytes32(0);
        }
        if (address(_feed) != _currentFeed) {
            __feedId_[address(_feed)] = _erc2362id;
        }
        _record.feed = _feed;
        emit PricePairSet(_erc2362id, _feed);
    }

    /// Returns list of known price pairs identifiers.
    function supportedPricePairs()
        external view
        virtual override
        returns (bytes32[] memory)
    {
        return __supportedPricePairs;
    }

    /// Returns `true` if given price pair is currently attached to a compliant price feed contract.
    function supportsPricePair(bytes32 _erc2362id)
        public view
        virtual override
        returns (bool)
    {
        return address(__pairs[_erc2362id].feed) != address(0);
    }

    /// Returns `true` if given price feed contract is currently attached to a known price pair. 
    function supportsPriceFeed(IERC165 _feed)
        public view
        virtual override
        returns (bool)
    {
        return __pairs[__feedId_[address(_feed)]].feed == _feed;
    }
}
