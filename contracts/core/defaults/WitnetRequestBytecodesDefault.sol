// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import "../WitnetUpgradableBase.sol";
import "../../WitnetRequestBytecodes.sol";
import "../../data/WitnetRequestBytecodesData.sol";
import "../../libs/WitnetEncodingLib.sol";

/// @title Witnet Request Board EVM-default implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBytecodesDefault
    is 
        WitnetRequestBytecodes,
        WitnetRequestBytecodesData,
        WitnetUpgradableBase
{   
    using Witnet for bytes;
    using Witnet for string;
    using WitnetV2 for WitnetV2.RadonSLA;
    
    using WitnetEncodingLib for Witnet.RadonDataRequestMethods;
    using WitnetEncodingLib for Witnet.RadonRetrieval;
    using WitnetEncodingLib for Witnet.RadonRetrieval[];
    using WitnetEncodingLib for Witnet.RadonReducer;
    using WitnetEncodingLib for Witnet.RadonSLA;
    using WitnetEncodingLib for Witnet.RadonDataTypes;

    function class()
        public view
        virtual override(WitnetRequestBytecodes, WitnetUpgradableBase) 
        returns (string memory)
    {
        return type(WitnetRequestBytecodesDefault).name;
    }

    bytes4 public immutable override specs = type(IWitnetRequestBytecodes).interfaceId;
    
    constructor(bool _upgradable, bytes32 _versionTag)
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.bytecodes"
        )
    {}

    receive() external payable {
        revert("WitnetRequestBytecodes: no transfers");
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
                revert("WitnetRequestBytecodes: not the owner");
            }
        }

        if (__bytecodes().base != address(0)) {
            // current implementation cannot be initialized more than once:
            if(__bytecodes().base == base()) {
                revert("WitnetRequestBytecodes: already initialized");
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
    // --- Implementation of 'IWitnetRequestBytecodes' -----------------------------------------------------------------------

    function bytecodeOf(bytes32 _radHash)
        public view
        override
        returns (bytes memory)
    {
        return __database().radsBytecode[_radHash];
    }

    function bytecodeOf(bytes32 _radHash, WitnetV2.RadonSLA calldata _sla)
        override external view 
        returns (bytes memory)
    {
        bytes memory _radBytecode = bytecodeOf(_radHash);
        return abi.encodePacked(
            WitnetEncodingLib.encode(uint64(_radBytecode.length), 0x0a),
            _radBytecode,
            _sla.toV1().encode()
        );
    }

    function bytecodeOf(bytes calldata _radBytecode, WitnetV2.RadonSLA calldata _sla)
        override external pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            WitnetEncodingLib.encode(uint64(_radBytecode.length), 0x0a),
            _radBytecode,
            _sla.toV1().encode()
        );
    }

    function hashOf(bytes calldata _radBytecode) external pure override returns (bytes32) {
        // todo: validate correctness of _radBytecode
        return _witnetHash(_radBytecode);
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
        DataProvider storage __provider = __database().providers[_index];
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
        returns (Witnet.RadonRetrieval memory _source)
    {
        _source = __database().retrievals[_hash];
        if (_source.method == Witnet.RadonDataRequestMethods.Unknown) {
            revert UnknownRadonRetrieval(_hash);
        }
    }

    function lookupRadonRetrievalArgsCount(bytes32 _hash)
        external view
        override
        returns (uint8)
    {
        if (__database().retrievals[_hash].method == Witnet.RadonDataRequestMethods.Unknown) {
            revert UnknownRadonRetrieval(_hash);
        }
        return __database().retrievals[_hash].argsCount;
    }

    function lookupRadonRetrievalResultDataType(bytes32 _hash)
        external view
        override
        returns (Witnet.RadonDataTypes)
    {
        if (__database().retrievals[_hash].method == Witnet.RadonDataRequestMethods.Unknown) {
            revert UnknownRadonRetrieval(_hash);
        }
        return __database().retrievals[_hash].resultDataType;
    }
    
    function lookupRadonReducer(bytes32 _hash)
        external view
        override
        returns (Witnet.RadonReducer memory _reducer)
    {   
        _reducer = __database().reducers[_hash];
        if (uint8(_reducer.opcode) == 0) {
            revert UnknownRadonReducer(_hash);
        }
    }

    function lookupRadonRequestAggregator(bytes32 _radHash)
        external view
        override
        returns (Witnet.RadonReducer memory)
    {
        return __database().reducers[
            __requests(_radHash).aggregator
        ];
    }

    function lookupRadonRequestResultDataType(bytes32 _radHash)
        external view
        override
        returns (Witnet.RadonDataTypes)
    {
        return __requests(_radHash).resultDataType;
    }

    function lookupRadonRequestResultMaxSize(bytes32 _radHash)
        external view
        override
        returns (uint16)
    {
        return uint16(__requests(_radHash).resultMaxSize);
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
        returns (Witnet.RadonReducer memory)
    {
        return __database().reducers[
            __requests(_radHash).tally
        ];
    }

    function verifyRadonRetrieval(
            Witnet.RadonDataRequestMethods _requestMethod,
            string calldata _requestURL,
            string calldata _requestBody,
            string[2][] memory  _requestHeaders,
            bytes calldata _requestRadonScript
        )
        public
        virtual override
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
            __database().retrievals[hash].method == Witnet.RadonDataRequestMethods.Unknown
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

                resultDataType:
                    WitnetEncodingLib.verifyRadonScriptResultDataType(_requestRadonScript),

                url:
                    _requestURL,

                body:
                    _requestBody,

                headers:
                    _requestHeaders,

                script:
                    _requestRadonScript
            });
            emit NewRadonRetrievalHash(hash);
        }
    }

    function verifyRadonReducer(Witnet.RadonReducer memory _reducer)
        external returns (bytes32 hash)
    {
        hash = keccak256(abi.encode(_reducer));
        Witnet.RadonReducer storage __reducer = __database().reducers[hash];
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
        returns (bytes32 _radHash)
    {
        // calculate unique hash
        bytes32 hash = keccak256(abi.encode(
            _retrievalsIds,
            _aggregatorId,
            _tallyId,
            _resultMaxSize,
            _args
        ));
        _radHash = __database().rads[hash];
        // verify, compose and register only if hash is not yet known:
        if (__database().rads[hash] == bytes32(0)) {
        
            // Check that at least one source is provided;
            if (_retrievalsIds.length == 0) {
                revert("WitnetRequestBytecodes: no retrievals");
            }
            
            // Check that number of args arrays matches the number of sources:
            if ( _retrievalsIds.length != _args.length) {
                revert("WitnetRequestBytecodes: args mismatch");
            }
            
            // Check sources and tally reducers:
            Witnet.RadonReducer memory _aggregator = __database().reducers[_aggregatorId];
            Witnet.RadonReducer memory _tally = __database().reducers[_tallyId];
            
            // Check result type consistency among all sources:
            Witnet.RadonDataTypes _resultDataType;
            Witnet.RadonRetrieval[] memory _retrievals = new Witnet.RadonRetrieval[](_retrievalsIds.length);
            for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
                _retrievals[_ix] = __database().retrievals[_retrievalsIds[_ix]];
                // Check all sources return same Radon data type:
                if (_ix == 0) {
                    _resultDataType = _retrievals[0].resultDataType;
                } else if (_retrievals[_ix].resultDataType != _resultDataType) {
                    revert("WitnetRequestBytecodes: mismatching retrievals");
                }
                // check enough args are provided for each source
                if (_args[_ix].length < uint(_retrievals[_ix].argsCount)) {
                    revert("WitnetRequestBytecodes: missing args");
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
                revert("WitnetRequestBytecodes: too heavy request");
            }
        
            // Calculate radhash and add request metadata and rad bytecode to storage:
            _radHash = _witnetHash(_bytecode);
            __database().rads[hash] = _radHash;
            __database().radsBytecode[_radHash] = _bytecode;
            __database().requests[_radHash] = DataRequest({
                aggregator: _aggregatorId,
                args: _args,
                radHash: _radHash,
                resultDataType: _resultDataType,
                resultMaxSize: _resultMaxSize,
                retrievals: _retrievalsIds,
                tally: _tallyId
            });
            emit NewRadHash(_radHash);
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
            Witnet.RadonReducer storage __reducer,
            Witnet.RadonFilter[] memory _filters
        )
        internal
        virtual
    {
        for (uint _ix = 0; _ix < _filters.length; _ix ++) {
            __reducer.filters.push(_filters[_ix]);
        }
    }

    function _witnetHash(bytes memory chunk) virtual internal pure returns (bytes32) {
        return sha256(chunk);
    }

}