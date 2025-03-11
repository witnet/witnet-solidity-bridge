// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

import "../WitOracleRequest.sol";
import "../WitOracleRequestTemplate.sol";

interface IWitPriceFeedsAdmin {

    event PriceFeedMapping(address indexed from, bytes32 id, string symbol, int8 exponent, address solver, string[] deps);
    event PriceFeedSettled(address indexed from, bytes32 id, string symbol, int8 exponent, Witnet.RadonHash radonHash);
    event PriceFeedRemoved(address indexed from, bytes32 id, string symbol);
    
    function acceptOwnership() external;
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function createMappingSolver(bytes calldata initcode, bytes calldata additionalParams) external returns (address);
    function determineMappingSolverAddress(bytes calldata initcode, bytes calldata additionalParams) external returns (address);
    function settleMinConfidence(Witnet.QuerySLA calldata confidence) external;
    function settleRadonBytecode(string calldata symbol, bytes calldata bytecode) external;
    function settleRadonHash(string calldata symbol, Witnet.RadonHash hash) external;
    function settleMapping(string calldata symbol, address solver, string[] calldata deps) external;
    function transferOwnership(address) external;
    function unsettle(string calldata caption) external;
}
