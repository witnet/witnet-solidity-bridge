// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IWitnetPriceSolver.sol";
import "../interfaces/IWitnetPriceSolverDeployer.sol";

import "../libs/Slices.sol";

/// @title Ancillary deployable library for WitnetPriceFeeds.
/// @dev Features:
/// @dev - deployment of counter-factual IWitnetPriceSolver instances.
/// @dev - validation of feed caption strings.
/// @author The Witnet Foundation.
library WitnetPriceFeedsLib {

    using Slices for string;
    using Slices for Slices.Slice;

    function deployPriceSolver(
            bytes calldata initcode,
            bytes calldata constructorParams
        )
        external
        returns (address _solver)
    {
        _solver = determinePriceSolverAddress(initcode, constructorParams);
        if (_solver.code.length == 0) {
            bytes memory _bytecode = _completeInitCode(initcode, constructorParams);
            address _createdContract;
            assembly {
                _createdContract := create2(
                    0, 
                    add(_bytecode, 0x20),
                    mload(_bytecode), 
                    0
                )
            }
            // assert(_solver == _createdContract); // fails on TEN chains
            _solver = _createdContract;
            require(
                IWitnetPriceSolver(_solver).specs() == type(IWitnetPriceSolver).interfaceId,
                "WitnetPriceFeedsLib: uncompliant solver implementation"
            );
        }
    }

    function determinePriceSolverAddress(
            bytes calldata initcode,
            bytes calldata constructorParams
        )
        public view
        returns (address)
    {
        return address(
            uint160(uint(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    bytes32(0),
                    keccak256(_completeInitCode(initcode, constructorParams))
                )
            )))
        );
    }

    function validateCaption(bytes32 prefix, string calldata caption)
        external pure
        returns (uint8)
    {
        require(
            bytes6(bytes(caption)) == bytes6(prefix),
            "WitnetPriceFeedsLib: bad caption prefix"
        );
        Slices.Slice memory _caption = caption.toSlice();
        Slices.Slice memory _delim = string("-").toSlice();
        string[] memory _parts = new string[](_caption.count(_delim) + 1);
        for (uint _ix = 0; _ix < _parts.length; _ix ++) {
            _parts[_ix] = _caption.split(_delim).toString();
        }
        (uint _decimals, bool _success) = Witnet.tryUint(_parts[_parts.length - 1]);
        require(_success, "WitnetPriceFeedsLib: bad decimals");
        return uint8(_decimals);
    }

    function _completeInitCode(bytes calldata initcode, bytes calldata constructorParams)
        private pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            initcode,
            constructorParams
        );
    } 

}
