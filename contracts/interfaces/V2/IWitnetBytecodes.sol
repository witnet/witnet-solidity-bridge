// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";

interface IWitnetBytecodes {
    
    event DrQueryHash(bytes32 drQueryHash);
    event DrRadonHash(bytes32 drRadonHash);
    event DrRadonTemplateHash(bytes32 drRadonTemplateHash, WitnetV2.Types[] types);
    event DrSlaHash(bytes32 drSlaHash);

    function bytecodeOf(bytes32 _drRadonHash) external view returns (bytes memory);
    function bytecodeOf(bytes32 _drRadonHash, bytes32 _drSlaHash) external view returns (bytes memory);
    function bytecodeOf(bytes32 _drRadonHash, bytes[] calldata _drArgs) external view returns (bytes memory);
    function bytecodeOf(bytes32 _drRadonHash, bytes32 _drSlaHash, bytes[] calldata _drArgs) external view returns (bytes memory);

    function hashOf(bytes32 _drRadonHash, bytes32 _drSlaHash) external pure returns (bytes32);
    function hashOf(bytes32 _drRadonHash, bytes32 _drSlaHash, bytes[] calldata _drArgs) external view returns (bytes32);

    function lookupDrSla(bytes32 _drSlaHash) external view returns (WitnetV2.DrSla memory);
    function lookupDrSlaReward(bytes32 _drSlaHash) external view returns (uint256);
    function lookupDrSources(bytes32 _drRadHash) external view returns (string[] memory);
    function lookupDrInputTypes(bytes32 _drRadonHash) external view returns (WitnetV2.Types[] memory);
    function lookupDrResultSize(bytes32 _drRadonHash) external view returns (uint256);
    function lookupDrResultType(bytes32 _drRadonHash) external view returns (WitnetV2.Types);

    function verifyDrRadonBytes(bytes calldata _drRadonBytes) external returns (bytes32 _drRadonHash);
    function verifyDrRadonTemplateBytes(bytes calldata _drRadonBytes, WitnetV2.Types[] calldata _types) external returns (bytes32 _drRadonHash);
    function verifyDrSla(WitnetV2.DrSla calldata _drSla) external returns (bytes32 _drSlaHash);

}