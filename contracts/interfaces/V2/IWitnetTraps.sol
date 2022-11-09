// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";

/// @title Witnet Request Board emitting events interface.
/// @author The Witnet Foundation.
interface IWitnetTraps {    

    event Trap(address indexed from, bytes32 _trapHash);
    event TrapIn(address indexed from, bytes32 _trapHash, uint256 _amount);
    event TrapOut(address indexed from, bytes32 _trapHash);

    function getTrapBalanceOf(address from, bytes32 _trapHash) external view returns (uint256);
    // function getTrapData(bytes32 _trapHash) external view returns (WitnetV2.TrapData memory);
    // function getTrapStatus(bytes32 _trapHash) external view returns (WitnetV2.TrapStatus);    

    function trap(bytes32 _drQueryHash, uint256 _pushInterval, uint256 _pushReward) external returns (bytes32 _trapHash);
    function push(bytes32 _drQueryHash, bytes32 _drHash/*, **/) external payable;
    function verifyPush(bytes32 _drQueryHash, bytes32 _drHash/*, **/) external payable;
    
    function trapIn(bytes32 _trapHash) external payable;
    function trapOut(bytes32 _trapHash) external;

    function totalTraps() external view returns (uint256);
    function totalPushes() external view returns (uint256);
    function totalDisputes() external view returns (uint256);

}