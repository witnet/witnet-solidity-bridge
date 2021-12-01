// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

// Inherits from:
import "ado-contracts/contracts/interfaces/IERC2362.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Uses:
import "../interfaces/IWitnetPricePoller.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WitnetPriceRegistry
    is
        IERC2362,
        Ownable
{
    using Strings for uint256;

    event PricePairSet(
        bytes32 indexed erc2362ID,
        IWitnetPricePoller witnetPricePoller
    );

    bytes32[] public supportedPricePairs;
    
    struct PricePair {
        address poller;
        uint256 decimals;
        string  base;
        string  quote;
    }    
    mapping (bytes32 => PricePair) internal _pairs;
    mapping (address => bytes32) internal _pollers;

    function getPricePoller(bytes32 _erc2362id)
        public view
        returns (IWitnetPricePoller)
    {
        return IWitnetPricePoller(_pairs[_erc2362id].poller);
    }

    function lookupERC2362ID(bytes32 _erc2362id)
        public view
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

    function setPricePoller(
            address _poller,
            uint256 _decimals,
            string calldata _base,
            string calldata _quote
        )
        external
        onlyOwner
    {
        if (_poller != address(0)) {
            require(
                IWitnetPricePoller(_poller).supportsInterface(type(IWitnetPricePoller).interfaceId),
                "WitnetPriceRegistry: non-compliant"
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
        address _currentPoller = _record.poller;
        if (bytes(_record.base).length == 0) {
            _record.base = _base;
            _record.quote = _quote;
            _record.decimals = _decimals;
            supportedPricePairs.push(_erc2362id);
        }
        else if (_currentPoller != address(0)) {
            _pollers[_currentPoller] = bytes32(0);
        }
        if (_poller != _currentPoller) {
            _pollers[_poller] = _erc2362id;
        }
        _record.poller = _poller;
        emit PricePairSet(_erc2362id, IWitnetPricePoller(_poller));
    }

    function supportedPricePair(bytes32 _erc2362id)
        public view
        returns (bool)
    {
        return _pairs[_erc2362id].poller != address(0);
    }

    function supportedPricePoller(address _poller)
        public view
        returns (bool)
    {
        return _pairs[_pollers[_poller]].poller == _poller;
    }

    /// Exposed function pertaining to EIP standards
	/// @param _erc2362id bytes32 ID of the query
	function valueFor(bytes32 _erc2362id)
        external view
        virtual override
        returns (
            int256 _value,
            uint256 _timestamp,
            uint256 _status
        )
    {
        IWitnetPricePoller _poller = getPricePoller(_erc2362id);
        if (address(_poller) != address(0)) {
            bytes32 _proof;
            (_value, _timestamp, _proof) = _poller.lastValue();
            _status = (_proof == bytes32(0)
                ? 404   // bad value
                : 200   // ok
            );
        } else {
            _status = 400; // not found
        }
    }
}
