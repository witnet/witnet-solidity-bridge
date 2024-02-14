// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetRequestBytecodes {

    error UnknownRadonRetrieval(bytes32 hash);
    error UnknownRadonReducer(bytes32 hash);
    error UnknownRadonRequest(bytes32 hash);

    event NewDataProvider(uint256 index);
    event NewRadonRetrievalHash(bytes32 hash);
    event NewRadonReducerHash(bytes32 hash);
    event NewRadHash(bytes32 hash);

    function bytecodeOf(bytes32 radHash) external view returns (bytes memory);
    function hashOf(bytes calldata) external view returns (bytes32);

    function lookupDataProvider(uint256 index) external view returns (string memory, uint);
    function lookupDataProviderIndex(string calldata authority) external view returns (uint);
    function lookupDataProviderSources(uint256 index, uint256 offset, uint256 length) external view returns (bytes32[] memory);

    function lookupRadonReducer(bytes32 hash) external view returns (Witnet.RadonReducer memory);
    
    function lookupRadonRetrieval(bytes32 hash) external view returns (Witnet.RadonRetrieval memory);
    function lookupRadonRetrievalArgsCount(bytes32 hash) external view returns (uint8);
    function lookupRadonRetrievalResultDataType(bytes32 hash) external view returns (Witnet.RadonDataTypes);
    
    function lookupRadonRequestAggregator(bytes32 radHash) external view returns (Witnet.RadonReducer memory);
    function lookupRadonRequestResultMaxSize(bytes32 radHash) external view returns (uint16);
    function lookupRadonRequestResultDataType(bytes32 radHash) external view returns (Witnet.RadonDataTypes);
    function lookupRadonRequestSources(bytes32 radHash) external view returns (bytes32[] memory);
    function lookupRadonRequestSourcesCount(bytes32 radHash) external view returns (uint);
    function lookupRadonRequestTally(bytes32 radHash) external view returns (Witnet.RadonReducer memory);
    
    function lookupRadonRAD(bytes32 radHash) external view returns (Witnet.RadonRAD memory);
    
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

    function totalDataProviders() external view returns (uint);

    /// ===============================================================================================================
    /// --- Deprecating methods ---------------------------------------------------------------------------------------

    // function lookupRadonSLA(bytes32 slaHash) external view returns (Witnet.RadonSLA memory);
   
}