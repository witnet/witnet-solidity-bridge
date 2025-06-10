// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/Witnet.sol";

interface IWitOracleRadonRegistryLegacy {

    function bytecodeOf(Witnet.RadonHash) external view returns (bytes memory);
    function lookupRadonRequest(Witnet.RadonHash radonRequestHash) external view returns (Witnet.RadonRequest memory);
    function lookupRadonRequestAggregator(Witnet.RadonHash radHash) external view returns (Witnet.RadonReducer memory);
    function lookupRadonRequestResultMaxSize(bytes32 radHash) external view returns (uint16);
    // function lookupRadonRequestRetrievalByIndex(Witnet.RadonHash radHash, uint256 index) external view returns (Witnet.RadonRetrieval memory);
    function lookupRadonRequestSources(bytes32 radHash) external view returns (bytes32[] memory);
    function lookupRadonRequestSourcesCount(bytes32 radHash) external view returns (uint);
    function lookupRadonRequestTally(Witnet.RadonHash radHash) external view returns (Witnet.RadonReducer memory);
    
    function verifyRadonRequest(
            bytes32[] calldata sources,
            bytes32 aggregator,
            bytes32 tally,
            uint16 resultMaxSize,
            string[][] calldata args
        ) external returns (bytes32 radHash);
}
