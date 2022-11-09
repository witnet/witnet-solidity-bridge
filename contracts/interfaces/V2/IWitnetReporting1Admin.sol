// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./IWitnetReporting1.sol";

/// @title Witnet Request Board emitting events interface.
/// @author The Witnet Foundation.
interface IWitnetReporting1Admin {

    function setSignUpConfig(IWitnetReporting1.SignUpConfig calldata) external;

}