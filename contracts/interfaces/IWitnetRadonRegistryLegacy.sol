// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetRadonRegistryLegacy {

    error UnknownRadonRetrieval(bytes32 hash);
    error UnknownRadonReducer(bytes32 hash);
    error UnknownRadonRequest(bytes32 hash);

    // function lookupDataProvider(uint256 index) external view returns (string memory, uint);
    // function lookupDataProviderIndex(string calldata authority) external view returns (uint);
    // function lookupDataProviderSources(uint256 index, uint256 offset, uint256 length) external view returns (bytes32[] memory);

    // function lookupRadonRetrievalResultDataType(bytes32 hash) external view returns (Witnet.RadonDataTypes);
    // function lookupRadonRequestResultDataType(bytes32 radHash) external view returns (Witnet.RadonDataTypes);
    
    function lookupRadonRequestResultMaxSize(bytes32 radHash) external view returns (uint16);
    function lookupRadonRequestSources(bytes32 radHash) external view returns (bytes32[] memory);
    function lookupRadonRequestSourcesCount(bytes32 radHash) external view returns (uint);
    
    
    function verifyRadonRequest(
            bytes32[] calldata sources,
            bytes32 aggregator,
            bytes32 tally,
            uint16 resultMaxSize,
            string[][] calldata args
        ) external returns (bytes32 radHash);
}
