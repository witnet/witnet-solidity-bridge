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
    using WitnetEncodingLib for WitnetV2.DataSource;
    using WitnetEncodingLib for WitnetV2.DataSource[];
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

    receive() external payable override {
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
    // --- Overrides 'Upgradable' -------------------------------------------------------------------------------------

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Must fail when trying to initialize same instance more than once.
    function initialize(bytes memory) 
        public
        virtual override
    {
        address _owner = __bytecodes().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            __bytecodes().owner = _owner;
        } else {
            // only owner can initialize:
            if (msg.sender != _owner) revert WitnetUpgradableBase.OnlyOwner(_owner);
        }

        if (__bytecodes().base != address(0)) {
            // current implementation cannot be initialized more than once:
            if(__bytecodes().base == base()) revert WitnetUpgradableBase.AlreadyInitialized(base());
        }        
        __bytecodes().base = base();

        emit Upgraded(msg.sender, base(), codehash(), version());
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

    function bytecodeOf(bytes32 _hash)
        public view
        override
        returns (bytes memory)
    {
        RadonRetrieval memory _retrieval = __retrievals(_hash);
        WitnetV2.DataSource[] memory _sources = new WitnetV2.DataSource[](_retrieval.sources.length);
        if (_sources.length == 0) {
            revert IWitnetBytecodes.UnknownRadonRetrieval(_hash);
        }
        for (uint _ix = 0; _ix < _retrieval.sources.length; _ix ++) {
            _sources[_ix] = __database().sources[_retrieval.sources[_ix]];
        }
        return _sources.encode(
            _retrieval.args,
            __database().reducers[_retrieval.aggregator].encode(),
            __database().reducers[_retrieval.tally].encode(),
            _retrieval.resultMaxSize
        );
    }

    function bytecodeOf(bytes32 _retrievalHash, bytes32 _slaHash)
        external view
        returns (bytes memory)
    {
        WitnetV2.RadonSLA storage __sla = __database().slas[_slaHash];
        if (__sla.numWitnesses == 0) {
            revert IWitnetBytecodes.UnknownRadonSLA(_slaHash);
        }
        return abi.encodePacked(
            bytecodeOf(_retrievalHash),
            __database().slas[_slaHash].encode()
        );
    }

    function hashOf(bytes32 _drRetrievalHash, bytes32 _drSlaHash)
        public pure 
        virtual override
        returns (bytes32)
    {
        return sha256(abi.encode(
            _drRetrievalHash,
            _drSlaHash
        ));
    }

    function hashWeightWitsOf(
            bytes32 _retrievalHash, 
            bytes32 _slaHash
        ) 
        external view
        virtual override
        returns (bytes32, uint32, uint256)
    {
        WitnetV2.RadonSLA storage __sla = __database().slas[_slaHash];
        if (__sla.numWitnesses == 0) {
            revert IWitnetBytecodes.UnknownRadonSLA(_slaHash);
        }
        RadonRetrieval storage __retrieval = __retrievals(_retrievalHash);
        if (__retrieval.weight == 0) {
            revert IWitnetBytecodes.UnknownRadonRetrieval(_retrievalHash);
        }
        return (
            hashOf(_retrievalHash, _slaHash),
            uint32(__retrieval.weight
                + __sla.numWitnesses * 636
                // + (8 + 2 + 8 + 4 + 8)
                + 100
            ),
            __sla.numWitnesses * uint(__sla.witnessReward)
        );
    }

    function lookupDataProvider(uint256 _index)
        external view
        override
        returns (
            string memory _fqdn,
            uint256 _totalSources
        )
    {
        return (
            __database().providers[_index].fqdn,
            __database().providers[_index].totalSources
        );
    }

    function lookupDataProviderIndex(string calldata _fqdn)
        external view
        override
        returns (uint256)
    {
        return __database().providersIndex[keccak256(abi.encodePacked(_fqdn))];
    }

    function lookupDataProviderSources(
            uint256 _index,
            uint256 _offset,
            uint256 _length
        )
        external view
        returns (bytes32[] memory _sources)
    {
        WitnetV2.DataProvider storage __provider = __database().providers[_index];
        uint _totalSources = __provider.totalSources;
        if (_offset < _totalSources){
            if (_offset + _length > _totalSources) {
                _length = _totalSources - _offset;
            }
            _sources = new bytes32[](_length);
            for (uint _ix = 0; _ix < _sources.length; _ix ++) {
                _sources[_ix] = __provider.sources[_ix + _offset];
            }
        }
    }

    function lookupDataSource(bytes32 _hash)
        external view
        override
        returns (WitnetV2.DataSource memory _source)
    {
        _source = __database().sources[_hash];
        if (_source.method == WitnetV2.DataRequestMethods.Unknown) {
            revert IWitnetBytecodes.UnknownDataSource(_hash);
        }
    }

    function lookupDataSourceResultDataType(bytes32 _hash)
        external view
        override
        returns (WitnetV2.RadonDataTypes)
    {
        if (__database().sources[_hash].method == WitnetV2.DataRequestsMethods.Unknown) {
            revert IWitnetBytecodes.UnknownDataSource(_hash);
        }
        return __database().sources[_hash].resultDataType;
    }
    
    function lookupRadonReducer(bytes32 _hash)
        external view
        override
        returns (WitnetV2.RadonReducer memory)
    {   
        return __database().reducers[_hash];
    }

    function lookupRadonRetrievalAggregator(bytes32 _drRetrievalHash)
        external view
        override
        returns (WitnetV2.RadonReducer memory)
    {
        return __database().reducers[
            __retrievals(_drRetrievalHash).aggregator
        ];
    }

    function lookupRadonRetrievalResultDataType(bytes32 _drRetrievalHash)
        external view
        override
        returns (WitnetV2.RadonDataTypes)
    {
        return __retrievals(_drRetrievalHash).resultDataType;
    }

    function lookupRadonRetrievalResultMaxSize(bytes32 _drRetrievalHash)
        external view
        override
        returns (uint256)
    {
        return __retrievals(_drRetrievalHash).resultMaxSize;
    }    

    function lookupRadonRetrievalSources(bytes32 _drRetrievalHash)
        external view
        override
        returns (bytes32[] memory)
    {
        return __retrievals(_drRetrievalHash).sources;
    }

    function lookupRadonRetrievalSourcesCount(bytes32 _drRetrievalHash)
        external view
        override
        returns (uint)
    {
        return __retrievals(_drRetrievalHash).sources.length;
    }

    function lookupRadonRetrievalTally(bytes32 _drRetrievalHash)
        external view
        override
        returns (WitnetV2.RadonReducer memory)
    {
        return __database().reducers[
            __retrievals(_drRetrievalHash).tally
        ];
    }

    function lookupRadonSLA(bytes32 _drSlaHash)
        external view
        override
        returns (WitnetV2.RadonSLA memory)
    {
        return __database().slas[_drSlaHash];
    }

    function lookupRadonSLAReward(bytes32 _drSlaHash)
        public view
        override
        returns (uint64)
    {
        WitnetV2.RadonSLA storage __sla = __database().slas[_drSlaHash];
        return __sla.numWitnesses * __sla.witnessReward;
    }

    function verifyDataSource(
            WitnetV2.DataRequestMethods _requestMethod,
            uint16 _resultMinRank,
            uint16 _resultMaxRank,
            string memory _requestSchema,
            string memory _requestFQDN,
            string memory _requestPath,
            string memory _requestQuery,
            string memory _requestBody,
            string[2][] memory _requestHeaders,
            bytes memory _requestRadonScript
        )
        external
        virtual override
        returns (bytes32 _hash)
    {   
        // lower case fqdn and schema, as they ought to be case-insenstive:
        _requestSchema = _requestSchema.toLowerCase();
        _requestFQDN = _requestFQDN.toLowerCase();

        // validate input params
        _requestMethod.validate(
            _resultMinRank,
            _resultMaxRank,
            _requestSchema,
            _requestFQDN,
            _requestPath,
            _requestQuery,
            _requestBody,
            _requestHeaders,
            _requestRadonScript
        );

        // compose data source struct in memory
        WitnetV2.DataSource memory _source = WitnetV2.DataSource({
            method:
                _requestMethod,

            resultDataType:
                WitnetEncodingLib.verifyRadonRequestScript(_requestRadonScript),

            url:
                string(abi.encodePacked(
                    _requestSchema,
                    _requestFQDN,
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
                _requestRadonScript,
                       
            resultMinRank:
                _resultMinRank,

            resultMaxRank:
                _resultMaxRank
        });

        // generate unique hash based on source metadata:
        _hash = keccak256(abi.encode(_source));

        // add metadata to storage if new:
        if (__database().sources[_hash].method == WitnetV2.DataRequestMethods.Unknown) {
            __database().sources[_hash] = _source;
            __pushDataProviderSource(_requestFQDN, _hash);
            emit NewDataSourceHash(_hash);
        }
    }

    function verifyRadonReducer(WitnetV2.RadonReducer memory _reducer)
        external returns (bytes32 _hash)
    {
        _reducer.validate();
        bytes memory _bytecode = _reducer.encode();
        _hash = _bytecode.hash();
        WitnetV2.RadonReducer storage __reducer = __database().reducers[_hash];
        if (uint8(__reducer.opcode) == 0 && __reducer.filters.length == 0) {
            __reducer.opcode = _reducer.opcode;
            __pushRadonReducerFilters(__reducer, _reducer.filters);
            emit NewRadonReducerHash(_hash, _bytecode);    
        }   
    }

    function verifyRadonRetrieval(
            WitnetV2.RadonDataTypes _resultDataType,
            uint16 _resultMaxSize,
            bytes32[] memory _sourcesHashes,
            string[][] memory _sourcesArgs,
            bytes32 _aggregatorHash,
            bytes32 _tallyHash
        )
        external
        virtual override
        returns (bytes32 _hash)
    {
        // Check provided result type and result max size:
        // TODO: revisit
        _resultMaxSize = _resultDataType.validate(_resultMaxSize);

        // Check that at least one source is provided;
        if (_sourcesHashes.length == 0) {
            revert WitnetV2.RadonRetrievalNoSources();
        }
        
        // Check that number of args arrays matches the number of sources:
        if ( _sourcesHashes.length != _sourcesArgs.length) {
            revert WitnetV2.RadonRetrievalSourcesArgsMismatch(
                _sourcesHashes.length,
                _sourcesArgs.length
            );
        }
        
        // Check sources and tally reducers:
        WitnetV2.RadonReducer memory _aggregator = __database().reducers[_aggregatorHash];
        WitnetV2.RadonReducer memory _tally = __database().reducers[_tallyHash];
        if (_tally.script.length > 0) {
            revert WitnetV2.UnsupportedRadonTallyScript(_tallyHash);
        }
        
        // Check result type consistency among all sources:
        WitnetV2.DataSource[] memory _sources = new WitnetV2.DataSource[](_sourcesHashes.length);
        for (uint _ix = 0; _ix < _sources.length; _ix ++) {
            _sources[_ix] = __database().sources[_sourcesHashes[_ix]];
            // Check all sources return same Radon data type:
            if (_sources[_ix].resultDataType != _resultDataType) {
                revert WitnetV2.RadonRetrievalResultsMismatch(
                    _ix,
                    uint8(_sources[_ix].resultDataType),
                    uint8(_resultDataType)
                );
            }
        }
        
        // Build radon retrieval bytecode:
        bytes memory _bytecode = _sources.encode(
            _sourcesArgs,
            _aggregator.encode(),
            _tally.encode(),
            _resultMaxSize
        );
        if (_bytecode.length > 65535) {
            revert WitnetV2.RadonRetrievalTooHeavy(_bytecode, _bytecode.length);
        }
        
        // Calculate hash and add metadata to storage if new:
        _hash = _bytecode.hash();
        
        if (__database().retrievals[_hash].sources.length == 0) {
            __database().retrievals[_hash] = RadonRetrieval({
                resultDataType: _resultDataType,
                resultMaxSize: _resultMaxSize,
                args: _sourcesArgs,
                sources: _sourcesHashes,
                aggregator: _aggregatorHash,
                tally: _tallyHash,
                weight: uint16(_bytecode.length)
            });
            emit NewRadonRetrievalHash(_hash, _bytecode);
        }
    }

    function verifyRadonSLA(WitnetV2.RadonSLA calldata _sla)
        external 
        virtual override
        returns (bytes32 _hash)
    {
        // Validate SLA params:
        _sla.validate();
        
        // Build RadonSLA bytecode:
        bytes memory _bytecode = _sla.encode();

        // Calculate hash and add to storage if new:
        _hash = _bytecode.hash();
        if (__database().slas[_hash].numWitnesses == 0) {
            __database().slas[_hash] = _sla;
            emit NewRadonSLAHash(_hash, _bytecode);
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
    
    function __pushDataProviderSource(string memory _fqdn, bytes32 _sourceHash)
        internal 
        virtual
        returns (bytes32 _hash)
    {
        if (bytes(_fqdn).length > 0) {
            _hash = keccak256(abi.encodePacked(_fqdn));
            uint _index = __database().providersIndex[_hash];
            if (_index == 0) {
                _index = ++ __bytecodes().totalDataProviders;
                __database().providersIndex[keccak256(bytes(_fqdn))] = _index;
                __database().providers[_index].fqdn = _fqdn;
                emit NewDataProvider(_index);
            }
            __database().providers[_index].sources[
                __database().providers[_index].totalSources ++
            ] = _sourceHash;
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