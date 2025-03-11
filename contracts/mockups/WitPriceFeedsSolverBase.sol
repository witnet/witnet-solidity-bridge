// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../data/WitPriceFeedsLegacyDataLib.sol";

abstract contract WitPriceFeedsSolverBase
    is
        IWitPriceFeedsLegacySolver
{
    /// ===============================================================================================================
    /// --- Yet to be implemented IWitPriceFeedsLegacySolver methods --------------------------------------------------------
    
    function class() virtual external pure returns (string memory);
    function solve(bytes4) virtual external view returns (Price memory);

    
    /// ===============================================================================================================
    /// --- Base implementation ---------------------------------------------------------------------------------------
    
    address public immutable override delegator;

    modifier onlyDelegator {
        require(
            address(this) == delegator,
            "WitPriceFeedsSolverBase: not the delegator"
        );
        _;
    }

    constructor() {
        delegator = msg.sender;
    }

    function specs() external pure returns (bytes4) {
        return type(IWitPriceFeedsLegacySolver).interfaceId;
    }

    function validate(bytes4 feedId, string[] calldata deps) virtual override external {
        bytes32 _depsFlag;
        uint256 _innerDecimals;
        require(
            deps.length <= 8,
            "WitPriceFeedsSolverBase: too many dependencies"
        );
        for (uint _ix = 0; _ix < deps.length; _ix ++) {
            bytes4 _depsId4 = bytes4(keccak256(bytes(deps[_ix])));
            WitPriceFeedsLegacyDataLib.Record storage __depsFeed = WitPriceFeedsLegacyDataLib.seekRecord(_depsId4);
            require(
                __depsFeed.index > 0, 
                string(abi.encodePacked(
                    "WitPriceFeedsSolverBase: unsupported ",
                    deps[_ix]
                ))
            );
            require(
                _depsId4 != feedId, 
                string(abi.encodePacked(
                    "WitPriceFeedsSolverBase: loop on ",
                    deps[_ix]
                ))
            );
            _depsFlag |= (bytes32(_depsId4) >> (32 * _ix));
            _innerDecimals += __depsFeed.decimals;
        }
        WitPriceFeedsLegacyDataLib.Record storage __feed = WitPriceFeedsLegacyDataLib.seekRecord(feedId);
        __feed.solverReductor = int(uint(__feed.decimals)) - int(_innerDecimals);
        __feed.solverDepsFlag = _depsFlag;
    }
}