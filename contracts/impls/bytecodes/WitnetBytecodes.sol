// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../WitnetUpgradableBase.sol";
import "../../data/WitnetBytecodesData.sol";

import "../../libs/WitnetLib.sol";

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
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetLib for uint64;
    using WitnetLib for WitnetV2.DataSource;
    using WitnetLib for WitnetV2.RadonSLA;
    using WitnetLib for WitnetV2.RadonDataTypes;    
    
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

    function bytecodeOf(bytes32 _drRetrievalHash)
        external view
        override
        returns (bytes memory)
    {
        return __database().retrievalsBytecode[_drRetrievalHash];
    }

    function bytecodeOf(bytes32 _drRetrievalHash, bytes32 _drSlaHash)
        external view
        returns (bytes memory)
    {
        return abi.encodePacked(
            __database().retrievalsBytecode[_drRetrievalHash],
            __database().slasBytecode[_drSlaHash]
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

    function lookupDataProvider(uint256 _index)
        external view
        override
        returns (WitnetV2.DataProvider memory)
    {
        return __database().providers[_index];
    }

    function lookupDataProviderIndex(string calldata _fqdn)
        external view
        override
        returns (uint256)
    {
        return __database().providersIndex[keccak256(abi.encodePacked(_fqdn))];
    }

    function lookupDataSource(bytes32 _drDataSourceHash)
        external view
        override
        returns (WitnetV2.DataSource memory)
    {
        return __database().sources[_drDataSourceHash];
    }

    function lookupRadonRetrievalAggregatorHash(bytes32 _drRetrievalHash)
        external view
        override
        returns (WitnetV2.RadonReducer memory)
    {
        return __database().reducers[
            __retrieval(_drRetrievalHash).aggregator
        ];
    }

    function lookupRadonRetrievalResultMaxSize(bytes32 _drRetrievalHash)
        external view
        override
        returns (uint256)
    {
        IWitnetBytecodes.RadonRetrieval storage __rr = __retrieval(_drRetrievalHash);
        return (__rr.resultMaxSize > 0
            ? __rr.resultMaxSize
            : __rr.resultType.size()
        );
    }

    function lookupRadonRetrievalResultType(bytes32 _drRetrievalHash)
        external view
        override
        returns (WitnetV2.RadonDataTypes)
    {
        return __retrieval(_drRetrievalHash).resultType;
    }

    function lookupRadonRetrievalSourceHashes(bytes32 _drRetrievalHash)
        external view
        override
        returns (bytes32[] memory)
    {
        return __retrieval(_drRetrievalHash).sources;
    }

    function lookupRadonRetrievalSourcesCount(bytes32 _drRetrievalHash)
        external view
        override
        returns (uint)
    {
        return __retrieval(_drRetrievalHash).sources.length;
    }

    function lookupRadonRetrievalTallyHash(bytes32 _drRetrievalHash)
        external view
        override
        returns (WitnetV2.RadonReducer memory)
    {
        return __database().reducers[
            __retrieval(_drRetrievalHash).tally
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
        external view
        returns (uint64)
    {
        WitnetV2.RadonSLA storage __sla = __database().slas[_drSlaHash];
        return __sla.numWitnesses * __sla.witnessReward;
    }

    function verifyDataSource(
            WitnetV2.DataRequestMethods _method,
            string memory _schema,
            string memory _fqdn,
            string memory _pathQuery,
            string memory _body,
            string[2][] memory _headers,            
            bytes memory _script
        )
        public
        virtual override
        returns (bytes32 _dataSourceHash)
    {   
        if (_headers[0].length != _headers[1].length) {
            revert UnsupportedDataRequestHeaders(_headers);
        }
        if (bytes(_fqdn).length > 0 ){
            __pushDataProvider(_fqdn);
        }
        WitnetV2.DataSource memory _dds = WitnetV2.DataSource({
            method: _verifyDataSourceMethod(_method, _schema),
            resultType: _verifyDataSourceScript(_script),
            url: string(abi.encodePacked(
                    _schema,
                    _fqdn,
                    bytes("/"),
                    _pathQuery
                )),
            body: _body,
            headers: _headers,
            script: _script
        });
        _dataSourceHash = keccak256(abi.encode(_dds));
        if (__database().sources[_dataSourceHash].method == WitnetV2.DataRequestMethods.Unknown) {
            __database().sources[_dataSourceHash] = _dds;
            emit NewDataSourceHash(_dataSourceHash, _dds.url);
        }
    }

    function verifyRadonReducer(WitnetV2.RadonReducer calldata _ddr)
        public
        virtual override 
        returns (bytes32 _ddrHash)
    {
        bytes memory _ddrBytes; 
        for (uint _ix = 0; _ix < _ddr.filters.length; ) {
            _ddrBytes = abi.encodePacked(
                _ddrBytes,
                _verifyDataFilter(_ddr.filters[_ix])
            );
            unchecked {
                _ix ++;
            }
        }
        _ddrBytes = abi.encodePacked(
            _ddrBytes,
            _verifyRadonReducerOps(_ddr.op)
        );
        _ddrHash = _ddrBytes.hash();
        if (__database().reducersBytecode[_ddrHash].length == 0) {
            __database().reducersBytecode[_ddrHash] = _ddrBytes;
            __database().reducers[_ddrHash] = _ddr;
            emit NewDataReducerHash(_ddrHash);
        }
    }

    function verifyRadonRetrieval(RadonRetrieval memory _retrieval)
        public
        virtual override
        returns (bytes32 _drRetrievalHash)
    {
        // Check number of provided sources and template args:
        if (_retrieval.sources.length == 0) {
            revert RadonRetrievalNoSources();
        }
        if ( _retrieval.sources.length != _retrieval.args.length) {
            revert RadonRetrievalArgsMismatch(_retrieval.args);
        }
        // Check provided result type and result max size:
        if (!_verifyDataTypeMaxSize(_retrieval.resultType, _retrieval.resultMaxSize)) {
            revert UnsupportedRadonDataType(
                uint8(_retrieval.resultType),
                _retrieval.resultMaxSize
            );
        }
        // Build data source bytecode in memory:
        bytes[] memory _sourcesBytecodes = new bytes[](_retrieval.sources.length);
        for (uint _ix = 0; _ix < _sourcesBytecodes.length; ) {
            WitnetV2.DataSource memory _ds = __database().sources[
                _retrieval.sources[_ix]
            ];
            // Check all result types of provided sources match w/ `_retrieval.resultType`
            if (_ds.resultType != _retrieval.resultType) {
                revert RadonRetrievalResultsMismatch(
                    uint8(_ds.resultType),
                    uint8(_retrieval.resultType)
                );
            }
            // Replace wildcards where needed:
            if (_retrieval.args[_ix].length > 0) {
                _ds = _replaceWildcards(_ds, _retrieval.args[_ix]);
            }
            // Encode data source:
            _sourcesBytecodes[_ix] = _ds.encode();
            unchecked {
                _ix ++;
            }
        }
        // Get pointer to aggregator bytecode in storage:
        bytes storage __aggregatorBytes = __database().reducersBytecode[_retrieval.aggregator];
        // Get pointer to tally bytecode in storage:
        bytes storage __tallyBytes;
        if (_retrieval.aggregator == _retrieval.tally) {
            __tallyBytes = __aggregatorBytes;
        } else {
            __tallyBytes = __database().reducersBytecode[_retrieval.tally];
            require(
                __tallyBytes.length > 0,
                "WitnetBytecodes: no tally"
            );
        }
        require(
            __aggregatorBytes.length > 0,
            "WitnetBytecodes: no aggregator"
        );
        // Build retrieval bytecode:
        bytes memory _retrievalBytes = _encodeRadonRetrieval(
            WitnetBuffer.concat(_sourcesBytecodes),
            __aggregatorBytes,
            __tallyBytes,
            _retrieval.resultMaxSize
        );
        // Calculate hash and add to storage if new:
        _drRetrievalHash = _retrievalBytes.hash();
        if (__database().retrievalsBytecode[_drRetrievalHash].length == 0) {
            __database().retrievalsBytecode[_drRetrievalHash] = _retrievalBytes;
            __database().retrievals[_drRetrievalHash] = _retrieval;
            emit NewRadonRetrievalHash(_drRetrievalHash);
        }
    }

    function verifyRadonSLA(WitnetV2.RadonSLA memory _drSla)
        external 
        virtual override
        returns (bytes32 _drSlaHash)
    {
        if (_drSla.witnessReward == 0) {
            revert RadonRetrievalNoSources();
        }
        if (_drSla.numWitnesses == 0) {
            revert RadonSlaNoWitnesses();
        } else if (_drSla.numWitnesses > 127) {
            revert RadonSlaTooManyWitnesses(_drSla.numWitnesses);
        }
        if (
            _drSla.minConsensusPercentage < 51 
                || _drSla.minConsensusPercentage > 99
        ) {
            revert RadonSlaConsensusOutOfRange(_drSla.minConsensusPercentage);
        }
        if (_drSla.collateral < 10 ** 9) {
            revert RadonSlaLowCollateral(_drSla.collateral);
        }
        bytes memory _drSlaBytecode = _drSla.encode();
        _drSlaHash = _drSlaBytecode.hash();
        if (__database().slasBytecode[_drSlaHash].length == 0) {           
            __database().slasBytecode[_drSlaHash] = _drSlaBytecode;
            __database().slas[_drSlaHash] = _drSla;
            emit NewDrSlaHash(_drSlaHash);
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
    // --- Internal view/pure methods ---------------------------------------------------------------------------------

    function _encodeRadonRetrieval(
            bytes memory _encodedSources,
            bytes memory _encodedAggregator,
            bytes memory _encodedTally,
            uint16 _resultMaxSize
        )
        virtual
        internal pure
        returns (bytes memory _encodedRetrieval)
    {
        _encodedRetrieval = abi.encodePacked(
            uint64(_encodedAggregator.length).encode(bytes1(0x1a)),
            uint64(_encodedTally.length).encode(bytes1(0x2a)),
            _encodeRadonRetrievalResultMaxSize(_resultMaxSize)
        );
        uint64 _retrievalSize = uint64(
            _encodedSources.length
                + _encodedRetrieval.length
        );
        return abi.encodePacked(
            _retrievalSize.encode(bytes1(0x0a)),
            _encodedSources,
            _encodedRetrieval
        );
    }

    function _encodeRadonRetrievalResultMaxSize(uint16 _maxsize)
        virtual
        internal pure
        returns (bytes memory _encodedMaxSize)
    {
        if (_maxsize > 0) {
            _encodedMaxSize = uint64(_maxsize).encode(0x28);
        }
    }

    function _replaceWildcards(
            WitnetV2.DataSource memory _ds,
            string[] memory _args
        )
        internal pure
        virtual
        returns (WitnetV2.DataSource memory)
    {
        _ds.url = string(WitnetBuffer.replace(bytes(_ds.url), _args));
        _ds.body = string(WitnetBuffer.replace(bytes(_ds.url), _args));
        WitnetCBOR.CBOR memory _cborScript = WitnetLib.replaceCborStringsFromBytes(_ds.script, _args);
        _ds.script = _cborScript.buffer.data;
        return _ds;
    }

    function _uint16InRange(uint16 _value, uint16 _min, uint16 _max)
        internal pure
        returns (bool)
    {
        return _value >= _min && _value <= _max;
    }

    function _verifyDataFilter(WitnetV2.RadonFilter memory _filter)
        internal pure
        virtual
        returns (bytes memory _filterBytes)
    {
        _filterBytes = _verifyDataFilterOps(_filter.op, _filter.cborArgs); 
        if (_filter.cborArgs.length > 0) {
            _filterBytes = abi.encodePacked(
                _filterBytes,
                uint64(_filter.cborArgs.length).encode(bytes1(0x12)),
                _filter.cborArgs
            );
        }
        return abi.encodePacked(
            uint64(_filterBytes.length).encode(bytes1(0x0a)),
            _filterBytes
        );
    }

    function _verifyDataFilterOps(WitnetV2.RadonFilterOpcodes _opcode, bytes memory _args)
        virtual
        internal pure
        returns (bytes memory)
    {
        if (
            _opcode == WitnetV2.RadonFilterOpcodes.StandardDeviation
                && _args.length == 0
                || _opcode != WitnetV2.RadonFilterOpcodes.Mode
        ) {
            revert UnsupportedRadonFilter(uint8(_opcode), _args);
        }
        return uint64(_opcode).encode(bytes1(0x08));
    }

    function _verifyRadonReducerOps(WitnetV2.RadonReducerOpcodes _reducer)
        virtual
        internal view
        returns (bytes memory)
    {
        if (!(
            _reducer == WitnetV2.RadonReducerOpcodes.AverageMean 
                || _reducer == WitnetV2.RadonReducerOpcodes.StandardDeviation
                || _reducer == WitnetV2.RadonReducerOpcodes.Mode
                || _reducer == WitnetV2.RadonReducerOpcodes.ConcatenateAndHash
                || _reducer == WitnetV2.RadonReducerOpcodes.AverageMedian
        )) {
            revert UnsupportedRadonReducer(uint8(_reducer));
        }
        return uint64(_reducer).encode(bytes1(0x10));
    }

    function _verifyDataSourceMethod(
            WitnetV2.DataRequestMethods _method,
            string memory _schema
        )
        virtual
        internal pure
        returns (WitnetV2.DataRequestMethods)
    {
        if (
            _method == WitnetV2.DataRequestMethods.Rng
                && keccak256(bytes(_schema)) != keccak256(bytes("https://"))
                && keccak256(bytes(_schema)) != keccak256(bytes("http://"))
            || !_uint16InRange(uint16(_method), uint16(1), uint16(3))                
        ) {
            revert UnsupportedDataRequestMethod(uint8(_method), _schema);
        }
        return _method;
    }

    function _verifyDataSourceCborScript(WitnetCBOR.CBOR memory _cbor)
        virtual 
        internal view
        returns (WitnetV2.RadonDataTypes _resultType)
    {
        if (_cbor.majorType == 4) {
            WitnetCBOR.CBOR[] memory _items = _cbor.readArray();
            if (_items.length > 1) {
                return _verifyDataSourceCborScript(
                    _items[_items.length - 2]
                );
            } else {
                return WitnetV2.RadonDataTypes.Any;
            }
        } else if (_cbor.majorType == 0) {
            return _lookupOpcodeResultType(uint8(_cbor.readUint()));
        } else {
            revert WitnetCBOR.UnexpectedMajorType(0, _cbor.majorType);
        }
    }

    function _verifyDataSourceScript(bytes memory _script)
        virtual
        internal view
        returns (WitnetV2.RadonDataTypes _resultType)
    {
        return _verifyDataSourceCborScript(
            WitnetCBOR.valueFromBytes(_script)
        );
    }

    function _verifyDataTypeMaxSize(WitnetV2.RadonDataTypes _dt, uint16 _maxsize)
        virtual
        internal pure
        returns (bool)
    {
        if (
            _dt == WitnetV2.RadonDataTypes.Array
                || _dt == WitnetV2.RadonDataTypes.Bytes 
                || _dt == WitnetV2.RadonDataTypes.Map
                || _dt == WitnetV2.RadonDataTypes.String 
        ) {
            return _uint16InRange(_maxsize, uint16(1), uint16(2048));
        } else {
            return _uint16InRange(uint16(_dt), uint16(1), uint16(type(WitnetV2.RadonDataTypes).max));
        }
    }

    
    // ================================================================================================================
    // --- Internal state-modifying methods ---------------------------------------------------------------------------
    
    function __pushDataProvider(string memory _fqdn)
        internal 
        virtual
        returns (bytes32 _hash)
    {
        _hash = keccak256(abi.encodePacked(_fqdn));
        uint _index = __database().providersIndex[_hash];
        if (_index == 0) {
            _index = ++ __bytecodes().totalDataProviders;
            __database().providers[_index] = WitnetV2.DataProvider({
                fqdn: _fqdn,
                totalSources: 1,
                totalRetrievals: 0
            });
            emit NewDataProvider(_fqdn, _index);
        } else {
            __database().providers[_index].totalSources ++;
        }
    }

}