// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../WitnetUpgradableBase.sol";
import "../../data/WitnetBytecodesData.sol";

import "../../libs/WitnetEncodingLib.sol";

/// @title Witnet Request Board "trustless" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetBytecodes
    is 
        WitnetUpgradableBase,
        WitnetBytecodesData
{
    using ERC165Checker for address;
    
    using Witnet for bytes;
    using WitnetLib for string;
    using WitnetEncodingLib for WitnetV2.DataRequestMethods;
    using WitnetEncodingLib for WitnetV2.RadonRetrieval;
    using WitnetEncodingLib for WitnetV2.RadonRetrieval[];
    using WitnetEncodingLib for WitnetV2.RadonReducer;
    using WitnetEncodingLib for WitnetV2.RadonSLA;
    using WitnetEncodingLib for WitnetV2.RadonDataTypes;    
    
    constructor(
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.bytecodes"
        )
    {}

    receive() external payable {
        revert("WitnetBytecodes: no transfers");
    }


    // ================================================================================================================
    // --- Overrides IERC165 interface --------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override(WitnetUpgradableBase, ERC165)
      returns (bool)
    {
        return _interfaceId == type(IWitnetBytecodes).interfaceId
            || super.supportsInterface(_interfaceId);
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
    function initialize(bytes memory) 
        public
        override
    {
        address _owner = __bytecodes().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            __bytecodes().owner = _owner;
        } else {
            // only owner can initialize:
            if (msg.sender != _owner) {
                revert WitnetUpgradableBase.OnlyOwner(_owner);
            }
        }

        if (__bytecodes().base != address(0)) {
            // current implementation cannot be initialized more than once:
            if(__bytecodes().base == base()) {
                revert WitnetUpgradableBase.AlreadyUpgraded(base());
            }
        }        
        __bytecodes().base = base();

        emit Upgraded(
            msg.sender,
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
    // --- Implementation of 'IWitnetBytecodes' -----------------------------------------------------------------------

    function bytecodeOf(bytes32 _radHash)
        public view
        override
        returns (bytes memory)
    {
        return __database().radsBytecode[_radHash];
    }

    function bytecodeOf(bytes32 _radHash, bytes32 _slaHash)
        external view
        returns (bytes memory)
    {
        WitnetV2.RadonSLA storage __sla = __database().slas[_slaHash];
        if (__sla.numWitnesses == 0) {
            revert IWitnetBytecodes.UnknownRadonSLA(_slaHash);
        }
        bytes memory _radBytecode = bytecodeOf(_radHash);
        return abi.encodePacked(
            WitnetEncodingLib.encode(uint64(_radBytecode.length), 0x0a),
            _radBytecode,
            __database().slasBytecode[_slaHash]
        );
    }

    function hashOf(
            bytes32[] calldata _retrievalsIds,
            bytes32 _aggregatorId,
            bytes32 _tallyId,
            uint16 _resultMaxSize,
            string[][] calldata _args
        )
        external pure
        virtual override
        returns (bytes32)
    {
        return keccak256(abi.encode(
            _retrievalsIds,
            _aggregatorId,
            _tallyId,
            _resultMaxSize,
            _args
        ));
    }

    function hashOf(bytes32 _radHash, bytes32 _slaHash)
        public pure 
        virtual override
        returns (bytes32)
    {
        return sha256(abi.encode(
            _radHash,
            _slaHash
        ));
    }

    function hashWeightWitsOf(
            bytes32 _radHash, 
            bytes32 _slaHash
        ) 
        external view
        virtual override
        returns (bytes32, uint32, uint256)
    {
        WitnetV2.RadonSLA storage __sla = __database().slas[_slaHash];
        {
            uint _numWitnesses = __sla.numWitnesses;
            uint _weight = __database().radsBytecode[_radHash].length;
            uint _witnessWits = __sla.witnessReward + 2 * __sla.minerCommitRevealFee;
            return (
                hashOf(_radHash, _slaHash),
                uint32(_weight
                    + _numWitnesses * 636
                    // + (8 + 2 + 8 + 4 + 8)
                    + 100
                ),
                _numWitnesses * _witnessWits
            );
        }
    }

    function lookupDataProvider(uint256 _index)
        external view
        override
        returns (string memory, uint256)
    {
        return (
            __database().providers[_index].authority,
            __database().providers[_index].totalEndpoints
        );
    }

    function lookupDataProviderIndex(string calldata _authority)
        external view
        override
        returns (uint256)
    {
        return __database().providersIndex[keccak256(abi.encodePacked(_authority))];
    }

    function lookupDataProviderSources(
            uint256 _index,
            uint256 _offset,
            uint256 _length
        )
        external view
        returns (bytes32[] memory _endpoints)
    {
        WitnetV2.DataProvider storage __provider = __database().providers[_index];
        uint _totalEndpoints = __provider.totalEndpoints;
        if (_offset < _totalEndpoints){
            if (_offset + _length > _totalEndpoints) {
                _length = _totalEndpoints - _offset;
            }
            _endpoints = new bytes32[](_length);
            for (uint _ix = 0; _ix < _endpoints.length; _ix ++) {
                _endpoints[_ix] = __provider.endpoints[_ix + _offset];
            }
        }
    }

    function lookupRadonRetrieval(bytes32 _hash)
        external view
        override
        returns (WitnetV2.RadonRetrieval memory _source)
    {
        _source = __database().retrievals[_hash];
        if (_source.method == WitnetV2.DataRequestMethods.Unknown) {
            revert IWitnetBytecodes.UnknownRadonRetrieval(_hash);
        }
    }

    function lookupRadonRetrievalArgsCount(bytes32 _hash)
        external view
        override
        returns (uint8)
    {
        if (__database().retrievals[_hash].method == WitnetV2.DataRequestMethods.Unknown) {
            revert IWitnetBytecodes.UnknownRadonRetrieval(_hash);
        }
        return __database().retrievals[_hash].argsCount;
    }

    function lookupRadonRetrievalResultDataType(bytes32 _hash)
        external view
        override
        returns (WitnetV2.RadonDataTypes)
    {
        if (__database().retrievals[_hash].method == WitnetV2.DataRequestMethods.Unknown) {
            revert IWitnetBytecodes.UnknownRadonRetrieval(_hash);
        }
        return __database().retrievals[_hash].resultDataType;
    }
    
    function lookupRadonReducer(bytes32 _hash)
        external view
        override
        returns (WitnetV2.RadonReducer memory _reducer)
    {   
        _reducer = __database().reducers[_hash];
        if (uint8(_reducer.opcode) == 0) {
            revert IWitnetBytecodes.UnknownRadonReducer(_hash);
        }
    }

    function lookupRadonRequestAggregator(bytes32 _radHash)
        external view
        override
        returns (WitnetV2.RadonReducer memory)
    {
        return __database().reducers[
            __requests(_radHash).aggregator
        ];
    }

    function lookupRadonRequestResultDataType(bytes32 _radHash)
        external view
        override
        returns (WitnetV2.RadonDataTypes)
    {
        return __requests(_radHash).resultDataType;
    }

    function lookupRadonRequestResultMaxSize(bytes32 _radHash)
        external view
        override
        returns (uint256)
    {
        return __requests(_radHash).resultMaxSize;
    }    

    function lookupRadonRequestSources(bytes32 _radHash)
        external view
        override
        returns (bytes32[] memory)
    {
        return __requests(_radHash).retrievals;
    }

    function lookupRadonRequestSourcesCount(bytes32 _radHash)
        external view
        override
        returns (uint)
    {
        return __requests(_radHash).retrievals.length;
    }

    function lookupRadonRequestTally(bytes32 _radHash)
        external view
        override
        returns (WitnetV2.RadonReducer memory)
    {
        return __database().reducers[
            __requests(_radHash).tally
        ];
    }

    function lookupRadonSLA(bytes32 _slaHash)
        external view
        override
        returns (WitnetV2.RadonSLA memory sla)
    {
        sla = __database().slas[_slaHash];
        if (sla.numWitnesses == 0) {
            revert IWitnetBytecodes.UnknownRadonSLA(_slaHash);
        }
    }

    function lookupRadonSLAReward(bytes32 _slaHash)
        public view
        override
        returns (uint)
    {
        WitnetV2.RadonSLA storage __sla = __database().slas[_slaHash];
        return __sla.numWitnesses * __sla.witnessReward;
    }

    function verifyRadonRetrieval(
            WitnetV2.DataRequestMethods _requestMethod,
            string memory _requestSchema,
            string memory _requestAuthority,
            string memory _requestPath,
            string memory _requestQuery,
            string memory _requestBody,
            string[2][] memory _requestHeaders,
            bytes memory _requestRadonScript
        )
        external
        virtual override
        returns (bytes32 hash)
    {   
        // lower case authority and schema, as they ought to be case-insenstive:
        _requestSchema = _requestSchema.toLowerCase();
        _requestAuthority = _requestAuthority.toLowerCase();

        // validate data source params
        hash = _requestMethod.validate(
            _requestSchema,
            _requestAuthority,
            _requestPath,
            _requestQuery,
            _requestBody,
            _requestHeaders,
            _requestRadonScript
        );

        // should it be a new data source:
        if (
            __database().retrievals[hash].method == WitnetV2.DataRequestMethods.Unknown
        ) {
            // compose data source and save it in storage:
            __database().retrievals[hash] = WitnetV2.RadonRetrieval({
                argsCount:
                    WitnetBuffer.argsCountOf(
                        abi.encode(
                            _requestAuthority, bytes(" "),
                            _requestPath, bytes(" "),
                            _requestQuery, bytes(" "),
                            _requestBody, bytes(" "),
                            _requestHeaders
                        )
                    ),

                method:
                    _requestMethod,

                resultDataType:
                    WitnetEncodingLib.verifyRadonScriptResultDataType(_requestRadonScript),

                url:
                    string(abi.encodePacked(
                        _requestSchema,
                        _requestAuthority,
                        bytes(_requestPath).length > 0
                            ? abi.encodePacked(bytes("/"), _requestPath)
                            : bytes(""),
                        bytes(_requestQuery).length > 0
                            ? abi.encodePacked("?", _requestQuery)
                            : bytes("")
                    )),

                body:
                    _requestBody,

                headers:
                    _requestHeaders,

                script:
                    _requestRadonScript
            });
            __pushDataProviderSource(_requestAuthority, hash);
            emit NewRadonRetrievalHash(hash);
        }
    }

    function verifyRadonReducer(WitnetV2.RadonReducer memory _reducer)
        external returns (bytes32 hash)
    {
        hash = keccak256(abi.encode(_reducer));
        WitnetV2.RadonReducer storage __reducer = __database().reducers[hash];
        if (
            uint8(__reducer.opcode) == 0
                && __reducer.filters.length == 0
        ) {
            _reducer.validate();
            __reducer.opcode = _reducer.opcode;
            __pushRadonReducerFilters(__reducer, _reducer.filters);
            emit NewRadonReducerHash(hash);
        }
    }

    function verifyRadonRequest(
            bytes32[] memory _retrievalsIds,
            bytes32 _aggregatorId,
            bytes32 _tallyId,
            uint16 _resultMaxSize,
            string[][] memory _args
        )
        external
        virtual override
        returns (bytes32 hash)
    {
        // calculate unique hash
        hash = keccak256(abi.encode(
            _retrievalsIds,
            _aggregatorId,
            _tallyId,
            _resultMaxSize,
            _args
        ));
        // verify, compose and register only if hash is not yet known:
        if (__database().requests[hash].tally == bytes32(0)) {
        
            // Check that at least one source is provided;
            if (_retrievalsIds.length == 0) {
                revert WitnetV2.RadonRequestNoSources();
            }
            
            // Check that number of args arrays matches the number of sources:
            if ( _retrievalsIds.length != _args.length) {
                revert WitnetV2.RadonRequestSourcesArgsMismatch(
                    _retrievalsIds.length,
                    _args.length
                );
            }
            
            // Check sources and tally reducers:
            WitnetV2.RadonReducer memory _aggregator = __database().reducers[_aggregatorId];
            WitnetV2.RadonReducer memory _tally = __database().reducers[_tallyId];
            if (_tally.script.length > 0) {
                revert WitnetV2.UnsupportedRadonTallyScript(_tallyId);
            }
            
            // Check result type consistency among all sources:
            WitnetV2.RadonDataTypes _resultDataType;
            WitnetV2.RadonRetrieval[] memory _retrievals = new WitnetV2.RadonRetrieval[](_retrievalsIds.length);
            for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
                _retrievals[_ix] = __database().retrievals[_retrievalsIds[_ix]];
                // Check all sources return same Radon data type:
                if (_ix == 0) {
                    _resultDataType = _retrievals[0].resultDataType;
                } else if (_retrievals[_ix].resultDataType != _resultDataType) {
                    revert WitnetV2.RadonRequestResultsMismatch(
                        _ix,
                        uint8(_retrievals[_ix].resultDataType),
                        uint8(_resultDataType)
                    );
                }
                // check enough args are provided for each source
                if (_args[_ix].length < uint(_retrievals[_ix].argsCount)) {
                    revert WitnetV2.RadonRequestMissingArgs(
                        _ix,
                        _retrievals[_ix].argsCount,
                        _args[_ix].length
                    );
                }
            }

            // Check provided result type and result max size:
            _resultMaxSize = _resultDataType.validate(_resultMaxSize);
            
            // Build radon retrieval bytecode:
            bytes memory _bytecode = _retrievals.encode(
                _args,
                _aggregator.encode(),
                _tally.encode(),
                _resultMaxSize
            );
            if (_bytecode.length > 65535) {
                revert WitnetV2.RadonRequestTooHeavy(_bytecode, _bytecode.length);
            }
        
            // Calculate radhash and add request metadata and rad bytecode to storage:
            bytes32 _radHash = _bytecode.hash();
            __database().requests[hash] = RadonRequest({
                aggregator: _aggregatorId,
                args: _args,
                radHash: _radHash,
                resultDataType: _resultDataType,
                resultMaxSize: _resultMaxSize,
                retrievals: _retrievalsIds,
                tally: _tallyId
            });
            __database().radsBytecode[_radHash] = _bytecode;
            emit NewRadHash(_radHash);
        }
    }

    function verifyRadonSLA(WitnetV2.RadonSLA calldata _sla)
        external 
        virtual override
        returns (bytes32 hash)
    {
        // Validate SLA params:
        _sla.validate();
        
        // Build RadonSLA bytecode:
        bytes memory _bytecode = _sla.encode();

        // Calculate hash and add to storage if new:
        hash = _bytecode.hash();
        if (__database().slas[hash].numWitnesses == 0) {
            __database().slas[hash] = _sla;
            __database().slasBytecode[hash] = _bytecode;
            emit NewSlaHash(hash);
        }
    }

    function totalDataProviders()
        external view
        override
        returns (uint)
    {
        return __bytecodes().totalDataProviders;
    }

    
    // ================================================================================================================
    // --- Internal state-modifying methods ---------------------------------------------------------------------------

    function __pushDataProviderSource(
            string memory _authority,
            bytes32 _retrievalHash
        )
        internal virtual
        returns (bytes32 _hash)
    {
        if (
            bytes(_authority).length > 0
                && WitnetBuffer.argsCountOf(bytes(_authority)) == 0
        ) {
            _hash = keccak256(abi.encodePacked(_authority));
            uint _index = __database().providersIndex[_hash];
            if (_index == 0) {
                _index = ++ __bytecodes().totalDataProviders;
                __database().providersIndex[keccak256(bytes(_authority))] = _index;
                __database().providers[_index].authority = _authority;
                emit NewDataProvider(_index);
            }
            __database().providers[_index].endpoints[
                __database().providers[_index].totalEndpoints ++
            ] = _retrievalHash;
        }
    }

    function __pushRadonReducerFilters(
            WitnetV2.RadonReducer storage __reducer,
            WitnetV2.RadonFilter[] memory _filters
        )
        internal
        virtual
    {
        for (uint _ix = 0; _ix < _filters.length; _ix ++) {
            __reducer.filters.push(_filters[_ix]);
        }
    }

}