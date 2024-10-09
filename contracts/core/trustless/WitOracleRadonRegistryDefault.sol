// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "../WitnetUpgradableBase.sol";
import "../../WitOracleRadonRegistry.sol";
import "../../data/WitOracleRadonRegistryData.sol";
import "../../interfaces/IWitOracleRadonRegistryLegacy.sol";
import "../../libs/WitOracleRadonEncodingLib.sol";

/// @title Witnet Request Board EVM-default implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitOracleRadonRegistryDefault
    is 
        WitOracleRadonRegistry,
        WitOracleRadonRegistryData,
        WitnetUpgradableBase,
        IWitOracleRadonRegistryLegacy
{   
    using Witnet for bytes;
    using Witnet for string;
    using Witnet for Witnet.RadonSLA;
    
    using WitOracleRadonEncodingLib for Witnet.RadonDataTypes;
    using WitOracleRadonEncodingLib for Witnet.RadonReducer;
    using WitOracleRadonEncodingLib for Witnet.RadonRetrieval;
    using WitOracleRadonEncodingLib for Witnet.RadonRetrieval[];
    using WitOracleRadonEncodingLib for Witnet.RadonRetrievalMethods;
    using WitOracleRadonEncodingLib for Witnet.RadonSLAv1;

    function class() public view virtual override(IWitAppliance, WitnetUpgradableBase)  returns (string memory) {
        return type(WitOracleRadonRegistryDefault).name;
    }

    bytes4 public immutable override specs = type(WitOracleRadonRegistry).interfaceId;

    modifier radonRequestExists(bytes32 _radHash) {
        _require(
            __database().requests[_radHash].aggregateTallyHashes != bytes32(0),
            "unverified data request"
        ); _;
    }
    
    modifier radonRetrievalExists(bytes32 _hash) {
        _require(
            __database().retrievals[_hash].method != Witnet.RadonRetrievalMethods.Unknown,
            "unverified data source"
        ); _;
    }

    constructor(bool _upgradable, bytes32 _versionTag)
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.bytecodes"
        )
    {}

    function _witOracleHash(bytes memory chunk) virtual internal pure returns (bytes32) {
        return sha256(chunk);
    }

    receive() external payable {
        _revert("no transfers");
    }

    
    // ================================================================================================================
    // --- Overrides 'Ownable2Step' -----------------------------------------------------------------------------------

    /// Returns the address of the pending owner.
    function pendingOwner()
        public view
        virtual override
        returns (address)
    {
        return __bytecodes().pendingOwner;
    }

    /// Returns the address of the current owner.
    function owner()
        public view
        virtual override
        returns (address)
    {
        return __bytecodes().owner;
    }

    /// Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        public
        virtual override
        onlyOwner
    {
        __bytecodes().pendingOwner = _newOwner;
        emit OwnershipTransferStarted(owner(), _newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`_newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    function _transferOwnership(address _newOwner)
        internal
        virtual override
    {
        delete __bytecodes().pendingOwner;
        address _oldOwner = owner();
        if (_newOwner != _oldOwner) {
            __bytecodes().owner = _newOwner;
            emit OwnershipTransferred(_oldOwner, _newOwner);
        }
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData) 
        public
        override
    {
        address _owner = __bytecodes().owner;
        if (_owner == address(0)) {
            // set owner from  the one specified in _initData
            _owner = abi.decode(_initData, (address));
            __bytecodes().owner = _owner;
        } else {
            // only owner can initialize:
            if (msg.sender != _owner) {
                _revert("not the owner");
            }
        }

        if (__bytecodes().base != address(0)) {
            // current implementation cannot be initialized more than once:
            if(__bytecodes().base == base()) {
                _revert("already initialized");
            }
        }        
        __bytecodes().base = base();

        emit Upgraded(
            _owner,
            base(),
            codehash(),
            version()
        );
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = __bytecodes().owner;
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }


    // ================================================================================================================
    // --- Implementation of 'IWitOracleRadonRegistry' -----------------------------------------------------------------------

    function bytecodeOf(bytes32 _radHash)
        public view override
        radonRequestExists(_radHash)
        returns (bytes memory)
    {
        return __database().radsBytecode[_radHash];
    }

    function bytecodeOf(bytes32 _radHash, Witnet.RadonSLA calldata _sla)
        override external view 
        returns (bytes memory)
    {
        bytes memory _radBytecode = bytecodeOf(_radHash);
        return abi.encodePacked(
            WitOracleRadonEncodingLib.encode(uint64(_radBytecode.length), 0x0a),
            _radBytecode,
            _sla.toV1().encode()
        );
    }

    function bytecodeOf(bytes calldata _radBytecode, Witnet.RadonSLA calldata _sla)
        override external pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            WitOracleRadonEncodingLib.encode(uint64(_radBytecode.length), 0x0a),
            _radBytecode,
            _sla.toV1().encode()
        );
    }

    function hashOf(bytes calldata _radBytecode) external pure override returns (bytes32) {
        // todo?: validate correctness of _radBytecode
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

    function lookupRadonRequest(bytes32 _radHash)
        override external view
        returns (Witnet.RadonRequest memory)
    {
        return Witnet.RadonRequest({
            retrieve:  lookupRadonRequestRetrievals(_radHash),
            aggregate: lookupRadonRequestAggregator(_radHash),
            tally:     lookupRadonRequestTally(_radHash)
        });
    }

    function lookupRadonRequestAggregator(bytes32 _radHash)
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

    function lookupRadonRequestTally(bytes32 _radHash)
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

    function lookupRadonRequestResultDataType(bytes32 _radHash)
        override external view
        radonRequestExists(_radHash)
        returns (Witnet.RadonDataTypes)
    {
        return lookupRadonRetrievalResultDataType(
            __database().requests[_radHash].retrievals[0]
        );
    }

    function lookupRadonRequestRetrievalByIndex(bytes32 _radHash, uint256 _index) 
        override external view 
        radonRequestExists(_radHash)
        returns (Witnet.RadonRetrieval memory)
    {
        _require(_index < __requests(_radHash).retrievals.length, "out of range");
        return __database().retrievals[
            __requests(_radHash).retrievals[_index]
        ];
    }

    function lookupRadonRequestRetrievals(bytes32 _radHash)
        override public view 
        radonRequestExists(_radHash)
        returns (Witnet.RadonRetrieval[] memory _retrievals)
    {
        _retrievals = new Witnet.RadonRetrieval[](__requests(_radHash).retrievals.length);
        for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
            _retrievals[_ix] = __database().retrievals[
                __requests(_radHash).retrievals[_ix]
            ];
        }
    }

    function verifyRadonReducer(Witnet.RadonReducer memory _reducer)
        virtual override public
        returns (bytes32 hash)
    {
        hash = bytes32(bytes16(keccak256(abi.encode(_reducer))));
        Witnet.RadonReducer storage __reducer = __database().reducers[hash];
        if (
            uint8(__reducer.opcode) == 0
                && __reducer.filters.length == 0
        ) {
            _reducer.validate();
            __reducer.opcode = _reducer.opcode;
            __pushRadonReducerFilters(__reducer, _reducer.filters);
            emit NewRadonReducer(bytes16(hash));
        }
    }
    
    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            Witnet.RadonReducer calldata _aggregateReducer,
            Witnet.RadonReducer calldata _tallyReducer
        ) 
        override external 
        returns (bytes32 radHash)
    {
        return __verifyRadonRequest(
            _retrieveHashes,
            new string[][](_retrieveHashes.length),
            _aggregateReducer,
            _tallyReducer
        );
    }

    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            bytes32 _aggregateReducerHash,
            bytes32 _tallyReducerHash
        )
        override external
        returns (bytes32 radHash)
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
        returns (bytes32)
    {
        return __verifyRadonRequest(
            _retrieveHashes, 
            _retrieveArgsValues, 
            _aggregateReducer, 
            _tallyReducer
        );
    }

    function verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            string[][] calldata _retrieveArgsValues,
            bytes32 _aggregateReducerHash,
            bytes32 _tallyReducerHash
        )
        override external
        returns (bytes32)
    {
        return __verifyRadonRequest(
            _retrieveHashes,
            _retrieveArgsValues,
            _aggregateReducerHash,
            _tallyReducerHash
        );
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

    function verifyRadonRetrieval(
            bytes32 _baseRetrieveHash,
            string calldata _lastArgValue
        )
        override external
        returns (bytes32)
    {
        Witnet.RadonRetrieval memory _retrieval = lookupRadonRetrieval(_baseRetrieveHash);
        _require(
            _retrieval.argsCount > 0,
            "non-parameterized radon retrieval"
        );
        _retrieval = _retrieval.replaceWildcards(
            _retrieval.argsCount - 1, 
            _lastArgValue
        );
        return verifyRadonRetrieval(
            _retrieval.method,
            _retrieval.url,
            _retrieval.body,
            _retrieval.headers,
            _retrieval.radonScript
        );
    }


    // ================================================================================================================
    // --- IWitOracleRadonRegistryLegacy ---------------------------------------------------------------------------------

    function lookupRadonRequestResultMaxSize(bytes32 _radHash) 
        override external view
        radonRequestExists(_radHash) 
        returns (uint16)
    {
        return 32;
    }

    function lookupRadonRequestSources(bytes32 _radHash) 
        override external view 
        radonRequestExists(_radHash)
        returns (bytes32[] memory)
    {
        return __requests(_radHash).retrievals;
    }

    function lookupRadonRequestSourcesCount(bytes32 _radHash)
        override external view 
        radonRequestExists(_radHash)
        returns (uint)
    {
        return __requests(_radHash).retrievals.length;
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
        return __verifyRadonRequest(
            _retrieveHashes,
            _retrieveArgsValues,
            lookupRadonReducer(_aggregateReducerHash),
            lookupRadonReducer(_tallyReducerHash)
        );
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
        returns (bytes32 _radHash)
    {   
        return __verifyRadonRequest(
            _retrieveHashes,
            _retrieveArgsValues,
            lookupRadonReducer(_aggregateReducerHash),
            lookupRadonReducer(_tallyReducerHash)
        );
    }

    function __verifyRadonRequest(
            bytes32[] calldata _retrieveHashes,
            string[][] memory _retrieveArgsValues,
            Witnet.RadonReducer memory _aggregateReducer,
            Witnet.RadonReducer memory _tallyReducer
        )
        virtual internal
        returns (bytes32 _radHash)
    {
        // calculate unique hashes:
        bytes32 _aggregateReducerHash = verifyRadonReducer(_aggregateReducer);
        bytes32 _tallyReducerHash = verifyRadonReducer(_tallyReducer);
        bytes32 hash = keccak256(abi.encode(
            _retrieveHashes,
            _aggregateReducerHash,
            _tallyReducerHash,
            _retrieveArgsValues
        ));
        
        // verify, compose and register only if hash is not yet known:
        _radHash = __database().rads[hash];
        if (__database().rads[hash] == bytes32(0)) {
        
            // Check that at least one source is provided;
            _require(
                _retrieveHashes.length > 0,
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
            
            // Build radon retrieval bytecode:
            bytes memory _bytecode = _retrievals.encode(
                _retrieveArgsValues, 
                _aggregateReducer.encode(),
                _tallyReducer.encode(),
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
            __database().requests[_radHash] = RadonRequestPacked({
                _args: new string[][](0),
                aggregateTallyHashes: (_aggregateReducerHash & 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000)
                    | (_tallyReducerHash >> 128),
                _radHash: bytes32(0),
                _resultDataType: Witnet.RadonDataTypes.Any,
                _resultMaxSize: 0,
                retrievals: _retrieveHashes,
                legacyTallyHash: bytes32(0)
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