// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";

interface IWitnetBytecodes {

    function bytecodeOf(bytes32 radHash) external view returns (bytes memory);
    function bytecodeOf(bytes32 radHash, bytes32 slahHash) external view returns (bytes memory);

    function hashOf(
            bytes32[] calldata sources,
            bytes32 aggregator,
            bytes32 tally,
            uint16 resultMaxSize,
            string[][] calldata args
        ) external pure returns (bytes32);
    function hashOf(bytes32 radHash, bytes32 slaHash) external pure returns (bytes32 drQueryHash);
    function hashWeightWitsOf(bytes32 radHash, bytes32 slaHash) external view returns (
            bytes32 drQueryHash,
            uint32  drQueryWeight,
            uint256 drQueryWits
        );

    function lookupDataProvider(uint256 index) external view returns (string memory, uint);
    function lookupDataProviderIndex(string calldata authority) external view returns (uint);
    function lookupDataProviderSources(uint256 index, uint256 offset, uint256 length) external view returns (bytes32[] memory);

    function lookupRadonReducer(bytes32 hash) external view returns (Witnet.RadonReducer memory);
    
    function lookupRadonRetrieval(bytes32 hash) external view returns (Witnet.RadonRetrieval memory);
    function lookupRadonRetrievalArgsCount(bytes32 hash) external view returns (uint8);
    function lookupRadonRetrievalResultDataType(bytes32 hash) external view returns (Witnet.RadonDataTypes);
    
    function lookupRadonRequestAggregator(bytes32 radHash) external view returns (Witnet.RadonReducer memory);
    function lookupRadonRequestResultMaxSize(bytes32 radHash) external view returns (uint256);
    function lookupRadonRequestResultDataType(bytes32 radHash) external view returns (Witnet.RadonDataTypes);
    function lookupRadonRequestSources(bytes32 radHash) external view returns (bytes32[] memory);
    function lookupRadonRequestSourcesCount(bytes32 radHash) external view returns (uint);
    function lookupRadonRequestTally(bytes32 radHash) external view returns (Witnet.RadonReducer memory);
    
    function lookupRadonSLA(bytes32 slaHash) external view returns (Witnet.RadonSLA memory);
    function lookupRadonSLAReward(bytes32 slaHash) external view returns (uint);
    
    function verifyRadonRetrieval(
            Witnet.RadonDataRequestMethods requestMethod,
            string calldata requestSchema,
            string calldata requestAuthority,
            string calldata requestPath,
            string calldata requestQuery,
            string calldata requestBody,
            string[2][] calldata requestHeaders,
            bytes calldata requestRadonScript
        ) external returns (bytes32 hash);
    
    function verifyRadonRetrieval(
            Witnet.RadonDataRequestMethods requestMethod,
            string calldata requestURL,
            string calldata requestBody,
            string[2][] calldata requestHeaders,
            bytes calldata requestRadonScript
        ) external returns (bytes32 hash);
    
    function verifyRadonReducer(Witnet.RadonReducer calldata reducer)
        external returns (bytes32 hash);
    
    function verifyRadonRequest(
            bytes32[] calldata sources,
            bytes32 aggregator,
            bytes32 tally,
            uint16 resultMaxSize,
            string[][] calldata args
        ) external returns (bytes32 radHash);
    
    function verifyRadonSLA(Witnet.RadonSLA calldata sla)
        external returns (bytes32 slaHash);

    function totalDataProviders() external view returns (uint);
   
}