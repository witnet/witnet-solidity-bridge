// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../interfaces/V2/IWitnetPriceSolver.sol";
import "../interfaces/V2/IWitnetPriceSolverDeployer.sol";

import "./Slices.sol";

/// @title Ancillary external library for WitnetPriceFeeds implementations.
/// @dev Features:
/// @dev - deployment of counter-factual IWitnetPriceSolver instances.
/// @dev - validation of feed caption strings.
/// @author The Witnet Foundation.
library WitnetPriceFeedsLib {

    using Slices for string;
    using Slices for Slices.Slice;

    function deployPriceSolver(
            bytes calldata initcode,
            bytes calldata additionalParams
        )
        external
        returns (address _solver)
    {
        _solver = determinePriceSolverAddress(initcode, additionalParams);
        if (_solver.code.length == 0) {
            bytes memory _bytecode = _completeInitCode(initcode, additionalParams);
            address _createdContract;
            assembly {
                _createdContract := create2(0, add(_bytecode, 0x20), mload(_bytecode), 0x0)
            }
            assert(_solver == _createdContract);
            require(
                IWitnetPriceSolver(_solver).class() == type(IWitnetPriceSolver).interfaceId,
                "WitnetPriceFeedsLib: uncompliant solver implementation"
            );
        }
    }

    function determinePriceSolverAddress(
            bytes calldata initcode,
            bytes calldata additionalParams
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
                    keccak256(_completeInitCode(initcode, additionalParams))
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

    function _completeInitCode(bytes calldata initcode, bytes calldata additionalParams)
        private view
        returns (bytes memory)
    {
        return abi.encodePacked(
            initcode, 
            abi.encode(address(this)),
            additionalParams
        );
    } 

}
