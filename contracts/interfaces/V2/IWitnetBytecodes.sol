// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../libs/WitnetV2.sol";

interface IWitnetBytecodes {

    struct RadonRetrieval {
        WitnetV2.RadonDataTypes resultType;
        uint16 resultMaxSize;
        string[][] args;
        bytes32[] sources;
        bytes32 aggregator;
        bytes32 tally;
    }
    
    error RadonRetrievalNoSources();
    error RadonRetrievalArgsMismatch(string[][] args);
    error RadonRetrievalResultsMismatch(uint8 read, uint8 expected);

    error RadonSlaNoReward();
    error RadonSlaNoWitnesses();
    error RadonSlaTooManyWitnesses(uint256 numWitnesses);
    error RadonSlaConsensusOutOfRange(uint256 percentage);
    error RadonSlaLowCollateral(uint256 collateral);

    error UnsupportedDataRequestMethod(uint8 method, string schema);
    error UnsupportedDataRequestHeaders(string[2][] headers);
    error UnsupportedRadonDataType(uint8 datatype, uint256 maxlength);
    error UnsupportedRadonFilter(uint8 filter, bytes args);
    error UnsupportedRadonReducer(uint8 reducer);
    error UnsupportedRadonScript(bytes script, uint256 offset);
    error UnsupportedRadonScriptOpcode(uint8 opcode);

    event NewDataProvider(string fqdn, uint256 index);
    event NewDataReducerHash(bytes32 hash);
    event NewDataSourceHash(bytes32 hash, string url);
    event NewRadonRetrievalHash(bytes32 hash);
    event NewDrSlaHash(bytes32 hash);

    function bytecodeOf(bytes32 _drRetrievalHash) external view returns (bytes memory);
    function bytecodeOf(bytes32 _drRetrievalHash, bytes32 _drSlaHash) external view returns (bytes memory);

    function hashOf(bytes32 _drRetrievalHash, bytes32 _drSlaHash) external pure returns (bytes32 _drQueryHash);

    function lookupDataProvider(uint256) external view returns (WitnetV2.DataProvider memory);
    function lookupDataProviderIndex(string calldata) external view returns (uint);
    function lookupDataSource(bytes32 _drDataSourceHash) external view returns (WitnetV2.DataSource memory);
    function lookupRadonRetrievalAggregatorHash(bytes32 _drRetrievalHash) external view returns (WitnetV2.RadonReducer memory);
    function lookupRadonRetrievalResultMaxSize(bytes32 _drRetrievalHash) external view returns (uint256);
    function lookupRadonRetrievalResultType(bytes32 _drRetrievalHash) external view returns (WitnetV2.RadonDataTypes);
    function lookupRadonRetrievalSourceHashes(bytes32 _drRetrievalHash) external view returns (bytes32[] memory);
    function lookupRadonRetrievalSourcesCount(bytes32 _drRetrievalHash) external view returns (uint);
    function lookupRadonRetrievalTallyHash(bytes32 _drRetrievalHash) external view returns (WitnetV2.RadonReducer memory);
    function lookupRadonSLA(bytes32 _drSlaHash) external view returns (WitnetV2.RadonSLA memory);
    function lookupRadonSLAReward(bytes32 _drSlaHash) external view returns (uint64);
    
    function verifyDataSource(
            WitnetV2.DataRequestMethods _requestMethod,
            string calldata _requestSchema,
            string calldata _requestFQDN,
            string calldata _requestPathQuery,
            string calldata _requestBody,
            string[2][] calldata _requestHeaders,
            bytes calldata _witnetScript
        ) external returns (bytes32);
    function verifyRadonReducer(WitnetV2.RadonReducer calldata) external returns (bytes32);
    function verifyRadonRetrieval(RadonRetrieval calldata) external returns (bytes32);
    function verifyRadonSLA(WitnetV2.RadonSLA calldata _drSla) external returns (bytes32);

    function totalDataProviders() external view returns (uint);
   
}