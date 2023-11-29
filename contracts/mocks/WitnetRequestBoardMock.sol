// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetBytecodesMock.sol";
import "../core/defaults/WitnetRequestBoardTrustableDefault.sol";

contract WitnetRequestBoardMock
    is
        WitnetRequestBoardTrustableDefault
{
    WitnetRequestFactory private __factory;

    constructor(WitnetBytecodesMock _registry) 
        WitnetRequestBoardTrustableDefault(
            WitnetRequestFactory(address(0)), 
            WitnetBytecodes(address(_registry)),
            false,
            bytes32("mocked"),
            60000, 65000, 70000, 20000
        )
    {
        __acls().isReporter_[msg.sender] = true;
    }

    function factory() override public view returns (WitnetRequestFactory) {
        return __factory;
    }

    function setFactory(WitnetRequestFactory _factory) external onlyOwner {
        __factory = _factory; 
    }
} 