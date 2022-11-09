// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../../libs/WitnetV2.sol";

/// @title Witnet Request Board emitting events interface.
/// @author The Witnet Foundation.
interface IWitnetReporting1 {

    error AlreadySignedUp(address reporter);

    event DrPostAccepted(address indexed from, bytes32 drHash);
    event DrPostRejected(address indexed from, bytes32 drHash, Witnet.ErrorCodes reason);
    
    event SignedUp(address indexed reporter, uint256 weiValue, uint256 totalReporters);
    event SigningOut(address indexed reporter, uint256 weiValue, uint256 totalReporters);
    event Slashed(address indexed reporter, uint256 weiValue, uint256 totalReporters);

    struct SignUpConfig {
        uint256 weiRejectionFee;
        uint256 weiSignUpFee;
        uint256 acceptanceBlocks;
        uint256 banningBlocks;
        uint256 exitBlocks;        
    }
    event SignUpConfigSet(address indexed from, SignUpConfig config);    

    function getReportingAddressByIndex(uint256) external view returns (address);
    function getReportingAddresses() external view returns (address[] memory);
    function getReportingSignUpConfig() external view returns (SignUpConfig memory);
    function isSignedUpReporter(address) external view returns (bool);
    function totalSignedUpReporters() external view returns (uint256);

    function signUp() external payable returns (uint256 _index);
    function signOut() external;

    function acceptDrPost(bytes32) external;
    function rejectDrPost(bytes32, Witnet.ErrorCodes) external payable;
}