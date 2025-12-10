// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "../../WitOracleRadonRegistry.sol";
import "../../data/WitOracleRadonRegistryData.sol";
import "../../interfaces/legacy/IWitOracleRadonRegistryLegacy.sol";
import "../../libs/WitOracleRadonEncodingLib.sol";

/// @title Witnet Request Board EVM-default implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
abstract contract WitOracleRadonRegistryBase
    is 
        WitOracleRadonRegistry,
        WitOracleRadonRegistryData,
        IWitOracleRadonRegistryLegacy
{   
    using Witnet for bytes;
    using Witnet for string;
    using Witnet for Witnet.QuerySLA;
    using Witnet for Witnet.RadonHash;
    
    using WitOracleRadonEncodingLib for Witnet.RadonDataTypes;
    using WitOracleRadonEncodingLib for Witnet.RadonReducer;
    using WitOracleRadonEncodingLib for Witnet.RadonRetrieval;
    using WitOracleRadonEncodingLib for Witnet.RadonRetrieval[];
    using WitOracleRadonEncodingLib for Witnet.RadonRetrievalMethods;
    using WitOracleRadonEncodingLib for Witnet.RadonSLAv1;

    modifier radonRequestExists(Witnet.RadonHash _radHash) {
        _require(
            __database().radsBytecode[_radHash].length > 0,
            "unverified data request"
        ); _;
    }
    
    modifier radonRetrievalExists(bytes32 _hash) {
        _require(
            __database().retrievals[_hash].method != Witnet.RadonRetrievalMethods.Unknown,
            "unverified data source"
        ); _;
    }

    function _witOracleHash(bytes memory chunk) virtual internal pure returns (Witnet.RadonHash) {
        return Witnet.RadonHash.wrap(sha256(chunk));
    }

    receive() external payable {
        _revert("no transfers");
    }


    // ================================================================================================================
    // --- Implementation of 'IWitOracleRadonRegistry' ----------------------------------------------------------------

    /// @notice Returns the Witnet-compliant DRO bytecode for some data request object 
    /// made out of the given Radon Request and Radon SLA security parameters. 
    function bytecodeOf(Witnet.RadonHash _radHash, Witnet.QuerySLA calldata _sla)
        override external view 
        returns (bytes memory)
    {
        bytes memory _radBytecode = lookupRadonRequestBytecode(_radHash);
        return abi.encodePacked(
            WitOracleRadonEncodingLib.encode(uint64(_radBytecode.length), 0x0a),
            _radBytecode,
            _sla.toV1().encode()
        );
    }

    /// @notice Returns the Witnet-compliant DRO bytecode for some data request object 
    /// made out of the given RAD bytecode and Radon SLA security parameters. 
    function bytecodeOf(bytes calldata _radBytecode, Witnet.QuerySLA calldata _sla)
        override external pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            WitOracleRadonEncodingLib.encode(uint64(_radBytecode.length), 0x0a),
            _radBytecode,
            _sla.toV1().encode()
        );
    }

    /// @notice Returns the hash of the given Witnet-compliant bytecode. Returned value
    /// can be used to trace back in the Witnet blockchain all past resolutions 
    /// of the given data request payload.
    function hashOf(bytes calldata _radBytecode) external pure override returns (Witnet.RadonHash) {
        return _witOracleHash(_radBytecode);
    }

    /// @notice Tells whether the specified Radon Reducer has been formally verified into the registry.
    function isVerifiedRadonReducer(bytes32 _radonReducerHash) external view override returns (bool) {
        return (
            uint8(__database().reducers[_radonReducerHash].method) != uint8(0)
        );
    }

    /// @notice Tells whether the given Radon Hash has been formally verified into the registry.
    function isVerifiedRadonRequest(Witnet.RadonHash _radonRequestHash) external view override returns (bool) {
        return (
            __database().radsBytecode[_radonRequestHash].length > 0
        );
    }

    /// @notice Tells whether the specified Radon Retrieval has been formally verified into the registry.
    function isVerifiedRadonRetrieval(bytes32 _radonRetrievalHash) external view override returns (bool) {
        return (
            __database().retrievals[_radonRetrievalHash].method != Witnet.RadonRetrievalMethods.Unknown
        );
    }

    /// @notice Returns the whole Witnet.RadonReducer metadata struct for the given hash.
    /// @dev Reverts if unknown.
    function lookupRadonReducer(bytes32 _hash)
        virtual override 
        public view
        returns (Witnet.RadonReducer memory _reducer)
    {   
        _reducer = __database().reducers[_hash];
        _require(uint8(_reducer.method) != 0, "unverified data reducer");
    }

    /// @notice Returns the Witnet-compliant RAD bytecode for some Radon Request 
    /// identified by its unique RAD hash. 
    function lookupRadonRequestBytecode(Witnet.RadonHash _radHash)
        public view override
        radonRequestExists(_radHash)
        returns (bytes memory)
    {
        return __database().radsBytecode[_radHash];
    }

    /// @notice Returns the deterministic data type returned by successful resolutions of the given Radon Request. 
    /// @dev Reverts if unknown.
    function lookupRadonRequestResultDataType(Witnet.RadonHash _radHash)
        override external view
        radonRequestExists(_radHash)
        returns (Witnet.RadonDataTypes _resultDataType)
    {
        _resultDataType = __database().radsInfo[_radHash].resultDataType;
        if (uint8(_resultDataType) == 0) {
            _resultDataType = lookupRadonRetrievalResultDataType(
                __database().legacyRequests[_radHash].retrievals[0]
            );
        }
    }

    /// @notice Returns the Tally reducer that is applied to aggregated values revealed by the witnessing nodes on the 
    /// Witnet blockchain. 
    /// @dev Reverts if unknown.
    function lookupRadonRequestCrowdAttestationTally(Witnet.RadonHash _radHash)
        override external view
        radonRequestExists(_radHash)
        returns (Witnet.RadonReducer memory)
    {
        return lookupRadonReducer(__database().radsInfo[_radHash].crowdAttestationTallyHash);
    }

    /// @notice Returns an array (one or more items) containing the introspective metadata of the given Radon Request's 
    /// data sources (i.e. Radon Retrievals). 
    /// @dev Reverts if unknown.
    function lookupRadonRequestRetrievals(Witnet.RadonHash _radHash)
        override public view 
        radonRequestExists(_radHash)
        returns (Witnet.RadonRetrieval[] memory _retrievals)
    {
        // TODO: disassemble radon request's bytecode into array of Radon Retrievals,
        // data structs need not to be saved in storage.
        _retrievals = new Witnet.RadonRetrieval[](__requests(_radHash).retrievals.length);
        for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
            _retrievals[_ix] = __database().retrievals[
                __requests(_radHash).retrievals[_ix]
            ];
        }
    }

    /// @notice Returns the Aggregate reducer that is applied to the data extracted from the data sources 
    /// (i.e. Radon Retrievals) whenever the given Radon Request gets solved on the Witnet blockchain. 
    /// @dev Reverts if unknown.
    function lookupRadonRequestRetrievalsAggregator(Witnet.RadonHash _radHash)
        override external view
        radonRequestExists(_radHash)
        returns (Witnet.RadonReducer memory)
    {
        return lookupRadonReducer(__database().radsInfo[_radHash].dataSourcesAggregatorHash);
    }

    /// @notice Returns the number of data sources referred by the specified Radon Request.
    /// @dev Reverts if unknown.
    function lookupRadonRequestRetrievalsCount(Witnet.RadonHash _radHash)
        override external view
        returns (uint8)
    {
        return __database().radsInfo[_radHash].dataSourcesCount;
    }

    /// @notice Returns introspective metadata of some previously verified Radon Retrieval (i.e. public data source). 
    ///@dev Reverts if unknown.
    function lookupRadonRetrieval(bytes32 _hash)
        override public view
        radonRetrievalExists(_hash)
        returns (Witnet.RadonRetrieval memory _source)
    {
        return __database().retrievals[_hash];
    }

    /// @notice Returns the number of indexed parameters required to be fulfilled when 
    /// eventually using the given Radon Retrieval. 
    /// @dev Reverts if unknown.
    function lookupRadonRetrievalArgsCount(bytes32 _hash)
        override external view
        radonRetrievalExists(_hash)
        returns (uint8)
    {
        return __database().retrievals[_hash].argsCount;
    }

    /// @notice Returns the type of the data that would be retrieved by the specified Radon Request (i.e. public data source). 
    /// @dev Reverts if unknown.
    function lookupRadonRetrievalResultDataType(bytes32 _hash)
        override public view
        radonRetrievalExists(_hash)
        returns (Witnet.RadonDataTypes)
    {
        return __database().retrievals[_hash].dataType;
    }

    /// @notice Verifies and registers on-chain the specified data source. 
    /// Returns a hash value that uniquely identifies the verified Data Source (aka. Radon Retrieval).
    /// All parameters but the request method are parameterizable by using embedded wildcard \x\ substrings (with x='0'..'9').
    /// @dev Reverts if:
    /// - unsupported request method is given;
    /// - no URL is provided in HTTP/* requests;
    /// - non-empty strings given on WIT/RNG requests.
    function verifyDataSource(Witnet.DataSource calldata _dataSource)
        virtual override public
        returns (bytes32)
    {
        return verifyRadonRetrieval(
            _dataSource.request.method,
            _dataSource.url,
            _dataSource.request.body,
            _dataSource.request.headers,
            _dataSource.request.script
        );
    }

    /// @notice Verifies and registers the given sequence of dataset filters and reducing function to be 
    /// potentially used as either Aggregate or Tally reducers within the resolution workflow
    /// of Radon Requests in the Wit/Oracle blockchain. Returns a hash value that uniquely identifies the 
    /// given Radon Reducer in the registry. 
    /// @dev Reverts if unsupported reducing or filtering methods are specified.
    function verifyRadonReducer(Witnet.RadonReducer memory _reducer)
        virtual override public
        returns (bytes32 hash)
    {
        hash = bytes32(bytes15(keccak256(abi.encode(_reducer))));
        Witnet.RadonReducer storage __reducer = __database().reducers[hash];
        if (
            uint8(__reducer.method) == 0
                // && __reducer.filters.length == 0
        ) {
            _reducer.validate();
            __reducer.method = _reducer.method;
            __pushRadonReducerFilters(__reducer, _reducer.filters);
            emit NewRadonReducer(hash);
        }
    }

    /// @notice Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals)
    /// and the aggregate and tally Radon Reducers. Returns a unique RAD hash that identifies the 
    /// verified Radon Request. 
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - any of passed retrievals is parameterized;
    /// - unsupported reducers are passed.
    function verifyRadonRequest(
            bytes32[] memory verifiedDataSources,
            Witnet.RadonReducer memory dataSourcesAggregator,
            Witnet.RadonReducer memory crowdAttestationTally
        ) 
        override public
        returns (Witnet.RadonHash radHash)
    {
        return __verifyRadonRequest(
            verifiedDataSources,
            new string[][](verifiedDataSources.length),
            verifyRadonReducer(dataSourcesAggregator),
            verifyRadonReducer(crowdAttestationTally)
        );
    }

    /// @notice Verifies and registers the specified Radon Request out of the given data sources (i.e. retrievals), 
    /// data sources parameters (if required), and some pre-verified aggregate and tally Radon Reducers. 
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - ranks of passed args don't match with those required by each given retrieval;
    /// - unverified reducers are passed.
    function verifyRadonRequest(
            bytes32[] calldata verifiedSources,
            bytes32 verifiedDataSourcesAggregator,
            bytes32 verifiedCrowdAttestationTally
        )
        override external
        returns (Witnet.RadonHash radHash)
    {
        return __verifyRadonRequest(
            verifiedSources,
            new string[][](verifiedSources.length),
            verifiedDataSourcesAggregator,
            verifiedCrowdAttestationTally
        );
    }

    /// @notice Verifies and registers the specified Radon Request out of some parameterized Radon Retrieval (i.e. data source), 
    /// the provided template parameters and the specified aggregate and tally Radon Reducers. 
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrievals are passed;
    /// - retrievals return different data types;
    /// - ranks of passed args don't match with those required by each given retrieval;
    /// - unsupported reducers are passed.
    function verifyRadonTemplateRequest(
            bytes32[] calldata verifiedDataSources,
            string[][] calldata templateArgs,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        ) 
        override external 
        returns (Witnet.RadonHash)
    {
        return __verifyRadonRequest(
            verifiedDataSources, 
            templateArgs, 
            verifyRadonReducer(dataSourcesAggregator), 
            verifyRadonReducer(crowdAttestationTally)
        );
    }

    /// @notice Verifies and registers a new Radon Request out of some parameterized Radon Retrieval (i.e. data source), 
    /// the provided template parameters and the specified aggregate and tally Radon Reducers. 
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// @dev Reverts if:
    /// - unverified retrieval is passed;
    /// - ranks of passed args don't match with those expected by given retrieval, after replacing the data provider URL.
    /// - unverified reducers are passed.
    function verifyRadonTemplateRequest(
            bytes32[] calldata verifiedDataSources,
            string[][] calldata templateArgs,
            bytes32 verifiedDataSourcesAggregator,
            bytes32 verifiedCrowdAttestationTally
        )
        override external
        returns (Witnet.RadonHash)
    {
        return __verifyRadonRequest(
            verifiedDataSources,
            templateArgs,
            verifiedDataSourcesAggregator,
            verifiedCrowdAttestationTally
        );
    }

    /// @notice Verifies and registers a new Radon Request out of some parametrized Radon Retrieval (i.e. data source).
    /// The Radon Request will replicate the Radon Retrieval as many times as the number of provided `modalUrls`, using
    /// the provided `modalArgs` to fulfill template parameters, and the specified aggretate and tally Radon Reducers.
    /// Returns a unique RAD hash that identifies the verified Radon Request.
    /// - unverified retrieval is passed;
    /// - ranks of passed args don't match with those expected by given retrieval, after replacing the data provider URL.
    /// - unverified reducers are passed.
    function verifyRadonModalRequest(
            bytes32 modalRetrieval,
            string[] calldata modalArgs,
            string[] calldata modalUrls,
            bytes32 verifiedDataSourcesAggregator,
            bytes32 verifiedCrowdAttestationTally
        )
        override public 
        returns (Witnet.RadonHash _radHash)
    {
        bytes32 hash = keccak256(abi.encode(
            modalRetrieval,
            modalUrls,
            modalArgs,
            verifiedDataSourcesAggregator,
            verifiedCrowdAttestationTally
        ));
        _radHash = __database().rads[hash];
        if (__database().rads[hash].isZero()) {
            Witnet.RadonRetrieval[] memory _retrievals = new Witnet.RadonRetrieval[](modalUrls.length);
            for (uint _ix = 0; _ix < modalUrls.length; ++ _ix) {
                if (_ix == 0) {
                    _retrievals[0] = lookupRadonRetrieval(modalRetrieval);
                } else {
                    _retrievals[_ix] = _retrievals[0];
                }
                _retrievals[_ix].url = modalUrls[_ix];
            }

            // Compose radon request bytecode:
            bytes memory _radBytecode = _retrievals.encode(
                modalArgs,
                __database().reducers[verifiedDataSourcesAggregator].encode(),
                __database().reducers[verifiedCrowdAttestationTally].encode()
            );
            _require(
                _radBytecode.length <= 65535,
                "too big request"
            );
            
            // Compute radhash 
            _radHash = _witOracleHash(_radBytecode);
            __database().rads[hash] = _radHash;
            // Add request metadata and rad bytecode to storage:
            __database().radsBytecode[_radHash] = _radBytecode;
            __database().radsInfo[_radHash] = RadonRequestInfo({
                crowdAttestationTallyHash: bytes15(verifiedCrowdAttestationTally),
                dataSourcesCount: uint8(modalUrls.length),
                dataSourcesAggregatorHash: bytes15(verifiedDataSourcesAggregator),
                resultDataType: _retrievals[0].dataType
            });
            
            // Emit event
            emit NewRadonRequest(_radHash);
        }
    }


    // ================================================================================================================
    // --- IWitOracleRadonRegistryLegacy ------------------------------------------------------------------------------

    function bytecodeOf(Witnet.RadonHash _radHash)
        external view override
        radonRequestExists(_radHash)
        returns (bytes memory)
    {
        return lookupRadonRequestBytecode(_radHash);
    }

    function lookupRadonRequest(Witnet.RadonHash _radHash)
        override external view
        returns (IWitOracleRadonRegistryLegacy.RadonRequest memory)
    {
        return IWitOracleRadonRegistryLegacy.RadonRequest({
            retrieve:  lookupRadonRequestRetrievals(_radHash),
            aggregate: lookupRadonRequestAggregator(_radHash),
            tally:     lookupRadonRequestTally(_radHash)
        });
    }

    function lookupRadonRequestAggregator(Witnet.RadonHash _radHash)
        override public view
        radonRequestExists(_radHash)
        returns (Witnet.RadonReducer memory)
    {
        if (__requests(_radHash).legacyTallyHash != bytes32(0)) {
            return lookupRadonReducer(__requests(_radHash).aggregateTallyHashes);
        } else {
            return lookupRadonReducer(bytes16(__requests(_radHash).aggregateTallyHashes));
        }
    }

    function lookupRadonRequestResultMaxSize(bytes32 _radHash) 
        override external view
        radonRequestExists(Witnet.RadonHash.wrap(_radHash)) 
        returns (uint16)
    {
        return 32;
    }

    function lookupRadonRequestSources(bytes32 _radHash) 
        override external view 
        radonRequestExists(Witnet.RadonHash.wrap(_radHash))
        returns (bytes32[] memory)
    {
        return __requests(Witnet.RadonHash.wrap(_radHash)).retrievals;
    }

    function lookupRadonRequestSourcesCount(bytes32 _radHash)
        override external view 
        radonRequestExists(Witnet.RadonHash.wrap(_radHash))
        returns (uint)
    {
        return __requests(Witnet.RadonHash.wrap(_radHash)).retrievals.length;
    }

    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            bytes32 _aggregateReducerHash,
            bytes32 _tallyReducerHash,
            uint16,
            string[][] calldata _retrieveArgsValues
        )
        virtual override public
        returns (bytes32)
    {
        return Witnet.RadonHash.unwrap(__verifyRadonRequest(
            _retrieveHashes,
            _retrieveArgsValues,
            _aggregateReducerHash,
            _tallyReducerHash
        ));
    }

    function verifyRadonRequest(
            bytes32 modalRetrieval,
            string[] calldata modalArgs,
            string[] calldata modalUrls,
            bytes32 verifiedDataSourcesAggregator,
            bytes32 verifiedCrowdAttestationTally
        )
        override external 
        returns (Witnet.RadonHash)
    {
        return verifyRadonModalRequest(
            modalRetrieval,
            modalArgs,
            modalUrls,
            verifiedDataSourcesAggregator,
            verifiedCrowdAttestationTally
        );
    }

    function lookupRadonRequestTally(Witnet.RadonHash _radHash)
        override public view
        radonRequestExists(_radHash)
        returns (Witnet.RadonReducer memory)
    {
        if (__requests(_radHash).legacyTallyHash != bytes32(0)) {
            return lookupRadonReducer(__requests(_radHash).legacyTallyHash);
        } else {
            return lookupRadonReducer(bytes16(__requests(_radHash).aggregateTallyHashes << 128));
        }
    }

    function verifyRadonRetrieval(
            Witnet.RadonRetrievalMethods _requestMethod,
            string memory _requestURL,
            string memory _requestBody,
            string[2][] memory  _requestHeaders,
            bytes memory _requestRadonScript
        )
        virtual override public
        returns (bytes32 hash)
    {
        // validate data source params
        hash = _requestMethod.validate(
            _requestURL, 
            _requestBody, 
            _requestHeaders, 
            _requestRadonScript
        );

        // should it be a new data source:
        if (
            __database().retrievals[hash].method == Witnet.RadonRetrievalMethods.Unknown
        ) {
            // compose data source and save it in storage:
            __database().retrievals[hash] = Witnet.RadonRetrieval({
                argsCount:
                    WitnetBuffer.argsCountOf(
                        abi.encode(
                            _requestURL, bytes(" "),
                            _requestBody, bytes(" "),
                            _requestHeaders, bytes(" "),
                            _requestRadonScript
                        )
                    ),

                method:
                    _requestMethod,

                dataType:
                    WitOracleRadonEncodingLib.verifyRadonScriptResultDataType(_requestRadonScript),

                url:
                    _requestURL,

                body:
                    _requestBody,

                headers:
                    _requestHeaders,

                radonScript:
                    _requestRadonScript
            });
            emit NewRadonRetrieval(hash);
        }
    }

    
    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function __verifyRadonRequest(
            bytes32[] memory _retrieveHashes,
            string[][] memory _retrieveArgsValues,
            bytes32 _aggregateReducerHash,
            bytes32 _tallyReducerHash
        )
        virtual internal
        returns (Witnet.RadonHash _radHash)
    {
        // calculate unique hash:
        bytes32 hash = keccak256(abi.encode(
            _retrieveHashes,
            _retrieveArgsValues,
            _aggregateReducerHash, 
            _tallyReducerHash
        ));
        
        // verify, compose and register only if hash is not yet known:
        _radHash = __database().rads[hash];
        if (__database().rads[hash].isZero()) {
        
            // Check that at least one source is provided;
            _require(
                _retrieveHashes.length > 0 && _retrieveHashes.length < 256,
                "no retrievals"
            );
            
            // Check that number of args arrays matches the number of sources:
            _require(
                _retrieveHashes.length == _retrieveArgsValues.length,
                "args mismatch"
            );
            
            // Check result type consistency among all sources:
            Witnet.RadonDataTypes _resultDataType;
            Witnet.RadonRetrieval[] memory _retrievals = new Witnet.RadonRetrieval[](_retrieveHashes.length);
            for (uint _ix = 0; _ix < _retrieveHashes.length; _ix ++) {
                _retrievals[_ix] = __database().retrievals[_retrieveHashes[_ix]];
                _require(
                    _retrievals[_ix].method != Witnet.RadonRetrievalMethods.Unknown,
                    "unknown retrieval"
                );
                // Check all sources return same Radon data type:
                if (_ix == 0) {
                    _resultDataType = _retrievals[0].dataType;
                } else if (_resultDataType != _retrievals[_ix].dataType) {
                    _revert("mismatching retrievals");
                }
                // check enough args are provided for each source
                if (_retrieveArgsValues[_ix].length != uint(_retrievals[_ix].argsCount)) {
                    _revert(string(abi.encodePacked(
                        "mismatching args count on retrieval #",
                        Witnet.toString(_ix + 1)
                    )));
                }
            }
            
            // Compose radon request bytecode:
            bytes memory _bytecode = _retrievals.encode(
                _retrieveArgsValues, 
                __database().reducers[_aggregateReducerHash].encode(),
                __database().reducers[_tallyReducerHash].encode(),
                0
            );
            _require(
                _bytecode.length <= 65535,
                "too big request"
            );
        
            // Calculate radhash and add request metadata and rad bytecode to storage:
            _radHash = _witOracleHash(_bytecode);
            __database().rads[hash] = _radHash;
            __database().radsBytecode[_radHash] = _bytecode;
            __database().radsInfo[_radHash] = RadonRequestInfo({
                crowdAttestationTallyHash: bytes15(_tallyReducerHash),
                dataSourcesCount: uint8(_retrieveHashes.length),
                dataSourcesAggregatorHash: bytes15(_aggregateReducerHash),
                resultDataType: _resultDataType
            });

            // Emit event
            emit NewRadonRequest(_radHash);
        }
    }

    function __pushRadonReducerFilters(
            Witnet.RadonReducer storage __reducer,
            Witnet.RadonFilter[] memory _filters
        )
        internal
    {
        for (uint _ix = 0; _ix < _filters.length; _ix ++) {
            __reducer.filters.push(_filters[_ix]);
        }
    }
}
