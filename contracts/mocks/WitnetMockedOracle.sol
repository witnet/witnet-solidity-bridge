// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetMockedRequestBytecodes.sol";
import "./WitnetMockedRequestFactory.sol";
import "../core/defaults/WitnetOracleTrustableDefault.sol";

import "./WitnetMockedPriceFeeds.sol";

/// @title Mocked implementation of `WitnetOracle`.
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS AND MAINNETS, PLEASE USE 
/// @dev THE `WitnetOracle` CONTRACT ADDRESS PROVIDED 
/// @dev BY THE WITNET FOUNDATION.
contract WitnetMockedOracle
    is
        WitnetOracleTrustableDefault
{
    WitnetRequestFactory private __factory;

    constructor(WitnetMockedRequestBytecodes _registry) 
        WitnetOracleTrustableDefault(
            WitnetRequestFactory(address(0)), 
            WitnetRequestBytecodes(address(_registry)),
            false,
            bytes32("mocked"),
            60000, 65000, 70000, 20000
        )
    {
        address[] memory _reporters = new address[](1);
        _reporters[0] = msg.sender;
        __setReporters(_reporters);
    }

    function factory() override public view returns (WitnetRequestFactory) {
        return __factory;
    }

    function setFactory(WitnetMockedRequestFactory _factory) external onlyOwner {
        __factory = WitnetRequestFactory(address(_factory)); 
    }
} 