// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IWitnetPriceRouter.sol";
import "ado-contracts/contracts/interfaces/IERC2362.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IWitnetPricePoller.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WitnetPriceRouter
    is
        IERC2362,
        IWitnetPriceRouter,
        Ownable
{
    using Strings for uint256;
    
    struct PricePair {
        address poller;
        uint256 decimals;
        string  base;
        string  quote;
    }    

    mapping (bytes32 => PricePair) internal _pairs;
    mapping (address => bytes32) internal _pollers;

    bytes32[] internal _pricePairs;

    // ========================================================================
    // --- Implementation of 'IWitnetPriceRouter' ---------------------------    

    function getPricePoller(bytes32 _erc2362id)
        public view
        virtual override
        returns (IERC165)
    {
        return IERC165(_pairs[_erc2362id].poller);
    }

    function getPricePollerCaption(IERC165 _poller) 
        public view
        virtual override
        returns (string memory)
    {
        require(supportsPricePoller(_poller), "WitnetPriceRouter: unknown");
        return lookupERC2362ID(_pollers[address(_poller)]);
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

    function setPricePoller(
            IERC165 _poller,
            uint256 _decimals,
            string calldata _base,
            string calldata _quote
        )
        public 
        virtual override
        onlyOwner
    {
        if (address(_poller) != address(0)) {
            require(
                IERC165(_poller).supportsInterface(type(IWitnetPricePoller).interfaceId),
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
        address _currentPoller = _record.poller;
        if (bytes(_record.base).length == 0) {
            _record.base = _base;
            _record.quote = _quote;
            _record.decimals = _decimals;
            _pricePairs.push(_erc2362id);
        }
        else if (_currentPoller != address(0)) {
            _pollers[_currentPoller] = bytes32(0);
        }
        if (address(_poller) != _currentPoller) {
            _pollers[address(_poller)] = _erc2362id;
        }
        _record.poller = address(_poller);
        emit PricePairSet(_erc2362id, _poller);
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
        return _pairs[_erc2362id].poller != address(0);
    }

    function supportsPricePoller(IERC165 _poller)
        public view
        virtual override
        returns (bool)
    {
        return _pairs[_pollers[address(_poller)]].poller == address(_poller);
    }


    // ========================================================================
    // --- Implementation of 'IERC2362' ---------------------------------------

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
        IWitnetPricePoller _poller = IWitnetPricePoller(address(getPricePoller(_erc2362id)));
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
