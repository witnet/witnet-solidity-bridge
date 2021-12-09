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

    mapping (bytes32 => PricePair) internal _pairs;
    mapping (address => bytes32) internal _feedId_;

    bytes32[] internal _pricePairs;

    // ========================================================================
    // --- Implementation of 'IWitnetPriceRouter' ---------------------------    

    function getPriceFeed(bytes32 _erc2362id)
        public view
        virtual override
        returns (IERC165)
    {
        return _pairs[_erc2362id].feed;
    }

    function getPriceFeedCaption(IERC165 _feed) 
        public view
        virtual override
        returns (string memory)
    {
        require(supportsPriceFeed(_feed), "WitnetPriceRouter: unknown");
        return lookupERC2362ID(_feedId_[address(_feed)]);
    }

    function hashPriceCaption(string memory _caption)
        public pure
        virtual override
        returns (bytes32)
    {
        return keccak256(bytes(_caption));
    }

    function lookupERC2362ID(bytes32 _erc2362id)
        public view
        virtual override
        returns (string memory _caption)
    {
        PricePair storage _pair = _pairs[_erc2362id];
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
        PricePair storage _record = _pairs[_erc2362id];
        address _currentFeed = address(_record.feed);
        if (bytes(_record.base).length == 0) {
            _record.base = _base;
            _record.quote = _quote;
            _record.decimals = _decimals;
            _pricePairs.push(_erc2362id);
        }
        else if (_currentFeed != address(0)) {
            _feedId_[_currentFeed] = bytes32(0);
        }
        if (address(_feed) != _currentFeed) {
            _feedId_[address(_feed)] = _erc2362id;
        }
        _record.feed = _feed;
        emit PricePairSet(_erc2362id, _feed);
    }

    function supportedPricePairs()
        external view
        virtual override
        returns (bytes32[] memory)
    {
        return _pricePairs;
    }

    function supportsPricePair(bytes32 _erc2362id)
        public view
        virtual override
        returns (bool)
    {
        return address(_pairs[_erc2362id].feed) != address(0);
    }

    function supportsPriceFeed(IERC165 _feed)
        public view
        virtual override
        returns (bool)
    {
        return _pairs[_feedId_[address(_feed)]].feed == _feed;
    }


    // ========================================================================
    // --- Implementation of 'IERC2362' ---------------------------------------

    /// Exposed function pertaining to EIP standards
	/// @param _erc2362id bytes32 ID of the query
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
}
