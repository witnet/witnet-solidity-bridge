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
    // --- Implementation of 'IWitOracleRadonRegistry' -----------------------------------------------------------------------

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

    function isVerifiedRadonReducer(bytes32 _radonReducerHash) external view override returns (bool) {
        return (
            uint8(__database().reducers[_radonReducerHash].opcode) != uint8(0)
        );
    }

    function isVerifiedRadonRequest(Witnet.RadonHash _radonRequestHash) external view override returns (bool) {
        return (
            __database().radsBytecode[_radonRequestHash].length > 0
        );
    }

    function isVerifiedRadonRetrieval(bytes32 _radonRetrievalHash) external view override returns (bool) {
        return (
            __database().retrievals[_radonRetrievalHash].method != Witnet.RadonRetrievalMethods.Unknown
        );
    }

    function hashOf(bytes calldata _radBytecode) external pure override returns (Witnet.RadonHash) {
        return _witOracleHash(_radBytecode);
    }

    function lookupRadonReducer(bytes32 _hash)
        virtual override 
        public view
        returns (Witnet.RadonReducer memory _reducer)
    {   
        _reducer = __database().reducers[_hash];
        _require(uint8(_reducer.opcode) != 0, "unverified data reducer");
    }

    function lookupRadonRequestBytecode(Witnet.RadonHash _radHash)
        public view override
        radonRequestExists(_radHash)
        returns (bytes memory)
    {
        return __database().radsBytecode[_radHash];
    }

    function lookupRadonRequestCrowdAttestationTally(Witnet.RadonHash _radHash)
        override external view
        radonRequestExists(_radHash)
        returns (Witnet.RadonReducer memory)
    {
        return lookupRadonReducer(__database().radsInfo[_radHash].crowdAttestationTallyHash);
    }

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

    function lookupRadonRequestRetrievalsAggregator(Witnet.RadonHash _radHash)
        override external view
        radonRequestExists(_radHash)
        returns (Witnet.RadonReducer memory)
    {
        return lookupRadonReducer(__database().radsInfo[_radHash].dataSourcesAggregatorHash);
    }

    function lookupRadonRequestRetrievalsCount(Witnet.RadonHash _radHash)
        override external view
        returns (uint8)
    {
        return __database().radsInfo[_radHash].dataSourcesCount;
    }

    function lookupRadonRetrieval(bytes32 _hash)
        override public view
        radonRetrievalExists(_hash)
        returns (Witnet.RadonRetrieval memory _source)
    {
        return __database().retrievals[_hash];
    }

    function lookupRadonRetrievalArgsCount(bytes32 _hash)
        override external view
        radonRetrievalExists(_hash)
        returns (uint8)
    {
        return __database().retrievals[_hash].argsCount;
    }

    function lookupRadonRetrievalResultDataType(bytes32 _hash)
        override public view
        radonRetrievalExists(_hash)
        returns (Witnet.RadonDataTypes)
    {
        return __database().retrievals[_hash].dataType;
    }

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

    function verifyRadonReducer(Witnet.RadonReducer memory _reducer)
        virtual override public
        returns (bytes32 hash)
    {
        hash = bytes32(bytes15(keccak256(abi.encode(_reducer))));
        Witnet.RadonReducer storage __reducer = __database().reducers[hash];
        if (
            uint8(__reducer.opcode) == 0
                // && __reducer.filters.length == 0
        ) {
            _reducer.validate();
            __reducer.opcode = _reducer.opcode;
            __pushRadonReducerFilters(__reducer, _reducer.filters);
            emit NewRadonReducer(hash);
        }
    }
    
    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            Witnet.RadonReducer calldata _aggregateReducer,
            Witnet.RadonReducer calldata _tallyReducer
        ) 
        override external 
        returns (Witnet.RadonHash radHash)
    {
        return __verifyRadonRequest(
            _retrieveHashes,
            new string[][](_retrieveHashes.length),
            verifyRadonReducer(_aggregateReducer),
            verifyRadonReducer(_tallyReducer)
        );
    }

    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            bytes32 _aggregateReducerHash,
            bytes32 _tallyReducerHash
        )
        override external
        returns (Witnet.RadonHash radHash)
    {
        return __verifyRadonRequest(
            _retrieveHashes,
            new string[][](_retrieveHashes.length),
            _aggregateReducerHash,
            _tallyReducerHash
        );
    }

    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            string[][] calldata _retrieveArgsValues,
            Witnet.RadonReducer calldata _aggregateReducer,
            Witnet.RadonReducer calldata _tallyReducer
        ) 
        override external 
        returns (Witnet.RadonHash)
    {
        return __verifyRadonRequest(
            _retrieveHashes, 
            _retrieveArgsValues, 
            verifyRadonReducer(_aggregateReducer), 
            verifyRadonReducer(_tallyReducer)
        );
    }

    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            string[][] calldata _retrieveArgsValues,
            bytes32 _aggregateReducerHash,
            bytes32 _tallyReducerHash
        )
        override external
        returns (Witnet.RadonHash)
    {
        return __verifyRadonRequest(
            _retrieveHashes,
            _retrieveArgsValues,
            _aggregateReducerHash,
            _tallyReducerHash
        );
    }

    function verifyRadonRequest(
            bytes32 commonRetrieveHash,
            string[] calldata commonRetrieveArgs,
            string[] calldata dataProviders,
            bytes32 dataSourcesAggregatorHash,
            bytes32 crowdAttestationTallyHash
        )
        override external 
        returns (Witnet.RadonHash _radHash)
    {
        bytes32 hash = keccak256(abi.encode(
            commonRetrieveHash,
            dataProviders,
            commonRetrieveArgs,
            dataSourcesAggregatorHash,
            crowdAttestationTallyHash
        ));
        _radHash = __database().rads[hash];
        if (__database().rads[hash].isZero()) {
            Witnet.RadonRetrieval[] memory _retrievals = new Witnet.RadonRetrieval[](dataProviders.length);
            for (uint _ix = 0; _ix < dataProviders.length; ++ _ix) {
                if (_ix == 0) {
                    _retrievals[0] = lookupRadonRetrieval(commonRetrieveHash);
                    _require(
                        _retrievals[0].method != Witnet.RadonRetrievalMethods.Unknown,
                        "unknown retrieval"
                    );
                    _require(
                        _retrievals[0].argsCount == commonRetrieveArgs.length + 1,
                        "mismatching args count"
                    );
                } else {
                    _retrievals[_ix] = _retrievals[0];
                }
            }

            // Compose radon request bytecode:
            bytes memory _radBytecode = _retrievals.encode(
                dataProviders,
                commonRetrieveArgs,
                __database().reducers[dataSourcesAggregatorHash].encode(),
                __database().reducers[crowdAttestationTallyHash].encode()
            );
            _require(
                _radBytecode.length <= 65535,
                "too big request"
            );
            
            // Compute radhash and add request metadata and rad bytecode to storage:
            _radHash = _witOracleHash(_radBytecode);
            __database().rads[hash] = _radHash;
            __database().radsBytecode[_radHash] = _radBytecode;
            __database().radsInfo[_radHash] = RadonRequestInfo({
                crowdAttestationTallyHash: bytes15(crowdAttestationTallyHash),
                dataSourcesCount: uint8(dataProviders.length),
                dataSourcesAggregatorHash: bytes15(dataSourcesAggregatorHash),
                resultDataType: _retrievals[0].dataType
            });
            
            // Emit event
            emit NewRadonRequest(_radHash);
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

    // function verifyRadonRetrieval(
    //         bytes32 _baseRetrieveHash,
    //         string calldata _lastArgValue
    //     )
    //     override external
    //     returns (bytes32)
    // {
    //     Witnet.RadonRetrieval memory _retrieval = lookupRadonRetrieval(_baseRetrieveHash);
    //     _require(
    //         _retrieval.argsCount > 0,
    //         "non-parameterized radon retrieval"
    //     );
    //     _retrieval = _retrieval.replaceWildcards(
    //         _retrieval.argsCount - 1, 
    //         _lastArgValue
    //     );
    //     return verifyRadonRetrieval(
    //         _retrieval.method,
    //         _retrieval.url,
    //         _retrieval.body,
    //         _retrieval.headers,
    //         _retrieval.radonScript
    //     );
    // }


    // ================================================================================================================
    // --- IWitOracleRadonRegistryLegacy ---------------------------------------------------------------------------------

    function bytecodeOf(Witnet.RadonHash _radHash)
        external view override
        radonRequestExists(_radHash)
        returns (bytes memory)
    {
        return lookupRadonRequestBytecode(_radHash);
    }

    function lookupRadonRequest(Witnet.RadonHash _radHash)
        override external view
        returns (Witnet.RadonRequest memory)
    {
        return Witnet.RadonRequest({
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

    // function lookupRadonRequestRetrievalByIndex(Witnet.RadonHash _radHash, uint256 _index) 
    //     override external view 
    //     radonRequestExists(_radHash)
    //     returns (Witnet.RadonRetrieval memory)
    // {
    //     _require(_index < __requests(_radHash).retrievals.length, "out of range");
    //     return __database().retrievals[
    //         __requests(_radHash).retrievals[_index]
    //     ];
    // }

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

    
    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function __verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
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
