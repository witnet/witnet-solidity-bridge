// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../WitOracleRadonRegistry.sol";
import "../../WitOracleRequestFactory.sol";
import "../../data/WitOracleRequestFactoryData.sol";
import "../../interfaces/IWitOracle.sol";
import "../../patterns/Clonable.sol";

abstract contract WitOracleRequestFactoryBase
    is
        Clonable,
        WitOracleRequest,
        WitOracleRequestFactory,
        WitOracleRequestFactoryData,
        WitOracleRequestTemplate
{
     /// @notice Reference to the Witnet Request Board that all templates built out from this factory will refer to.
    WitOracle immutable public override witOracle;

    modifier notOnFactory virtual {
        _require(
            address(this) != self(),
            "not on factory"
        ); _;
    }

    modifier onlyOnFactory virtual {
        _require(
            address(this) == self(),
            "not the factory"
        ); _;
    }

    modifier onlyOnRequests {
        _require(
            __witOracleRequest().radHash != bytes32(0),
            "not a request"
        ); _;
    }

    modifier onlyOnTemplates {
        _require(
            __witOracleRequestTemplate().tallyReduceHash != bytes32(0),
            "not a template"
        ); _;
    }

    constructor(WitOracle _witOracle) {
        witOracle = _witOracle;
    }

    function _getWitOracleRadonRegistry() virtual internal view returns (WitOracleRadonRegistry) {
        return witOracle.registry();
    }

    function initializeWitOracleRequest(bytes32 _radHash)
        virtual public initializer
        returns (address)
    {
        _require(_radHash != bytes32(0), "no rad hash?");
        __witOracleRequest().radHash = _radHash;   
        return address(this);
    }

    function initializeWitOracleRequestTemplate(
            bytes32[] calldata _retrieveHashes,
            bytes16 _aggregateReducerHash,
            bytes16 _tallyReducerHash
        )
        virtual public initializer
        returns (address)
    {   
        _require(_retrieveHashes.length > 0, "no retrievals?");
        _require(_aggregateReducerHash != bytes16(0), "no aggregate reducer?");
        _require(_tallyReducerHash != bytes16(0), "no tally reducer?");

        WitOracleRequestTemplateStorage storage __data = __witOracleRequestTemplate();
        __data.retrieveHashes = _retrieveHashes;
        __data.aggregateReduceHash = _aggregateReducerHash;
        __data.tallyReduceHash = _tallyReducerHash;
        return address(this);
    }

    // ================================================================================================================
    /// --- Overrides Clonable ----------------------------------------------------------------------------------------

    /// @notice Tells whether a WitOracleRequest or a WitOracleRequestTemplate has been properly initialized.
    function initialized()
        virtual override(Clonable)
        public view
        returns (bool)
    {
        return (
            __witOracleRequestTemplate().tallyReduceHash != bytes16(0)
                || __witOracleRequest().radHash != bytes32(0)
        );
    }

    // /// @notice Contract address to which clones will be re-directed.
    // function self()
    //     virtual override
    //     public view
    //     returns (address)
    // {
    //     return (__proxy() != address(0)
    //         ? __implementation()
    //         : base()
    //     );
    // }


    /// ===============================================================================================================
    /// --- IWitOracleRequestFactory, IWitOracleRequestTemplate, IWitOracleRequest polymorphic methods ----------------

    function class() virtual override public view returns (string memory) {
        if (__witOracleRequest().radHash != bytes32(0)) {
            return type(WitOracleRequest).name;
        } else if (__witOracleRequestTemplate().tallyReduceHash != bytes16(0)) {
            return type(WitOracleRequestTemplate).name;
        } else {
            return type(WitOracleRequestFactory).name;
        }
    }

    function specs() 
        virtual override
        external view
        returns (bytes4)
    {
        if (__witOracleRequest().radHash != bytes32(0)) {
            return (
                type(IWitOracleAppliance).interfaceId
                    ^ type(IWitOracleRequest).interfaceId
            );
        } else if (__witOracleRequestTemplate().tallyReduceHash != bytes16(0)) {
            return (
                type(IWitOracleAppliance).interfaceId
                    ^ type(IWitOracleRequestTemplate).interfaceId
            );
        } else {
            return (
                type(IWitOracleAppliance).interfaceId
                    ^ type(IWitOracleRequestFactory).interfaceId
            );
        }
    }

    
    /// ===============================================================================================================
    /// --- IWitOracleRequestTemplate, IWitOracleRequest polymorphic methods ------------------------------------------

    function getRadonReducers()
        virtual override (IWitOracleRequest, IWitOracleRequestTemplate)
        external view
        notOnFactory
        returns (Witnet.RadonReducer memory, Witnet.RadonReducer memory)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();
        if (__witOracleRequest().radHash != bytes32(0)) {
            return (
                _registry.lookupRadonRequestAggregator(__witOracleRequest().radHash),
                _registry.lookupRadonRequestTally(__witOracleRequest().radHash)
            );
        } else {
            return (
                _registry.lookupRadonReducer(__witOracleRequestTemplate().aggregateReduceHash),
                _registry.lookupRadonReducer(__witOracleRequestTemplate().tallyReduceHash)
            );
        }
    }

    function getRadonRetrievalByIndex(uint256 _index)
        virtual override (IWitOracleRequest, IWitOracleRequestTemplate)
        external view 
        notOnFactory
        returns (Witnet.RadonRetrieval memory)
    {
        if (__witOracleRequest().radHash != bytes32(0)) {
            return _getWitOracleRadonRegistry().lookupRadonRequestRetrievalByIndex(
                __witOracleRequest().radHash,
                _index
            );
        } else {
            _require(
                _index < __witOracleRequestTemplate().retrieveHashes.length, 
                "index out of range"
            );
            return _getWitOracleRadonRegistry().lookupRadonRetrieval(
                __witOracleRequestTemplate().retrieveHashes[_index]
            );
        }
    }

    function getRadonRetrievals()
        virtual override (IWitOracleRequest, IWitOracleRequestTemplate)
        external view
        notOnFactory
        returns (Witnet.RadonRetrieval[] memory _retrievals)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();
        if (__witOracleRequest().radHash != bytes32(0)) {
            return _registry.lookupRadonRequestRetrievals(
                __witOracleRequest().radHash
            );
        } else {
            _retrievals = new Witnet.RadonRetrieval[](__witOracleRequestTemplate().retrieveHashes.length);
            for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
                _retrievals[_ix] = _registry.lookupRadonRetrieval(
                    __witOracleRequestTemplate().retrieveHashes[_ix]
                );
            }
        }
    }

    function getResultDataType() 
        virtual override (IWitOracleRequest, IWitOracleRequestTemplate)
        external view
        notOnFactory
        returns (Witnet.RadonDataTypes)
    {
        if (__witOracleRequest().radHash != bytes32(0)) {
            return _getWitOracleRadonRegistry().lookupRadonRequestResultDataType(
                __witOracleRequest().radHash
            );
        } else {
            return _getWitOracleRadonRegistry().lookupRadonRetrievalResultDataType(
                __witOracleRequestTemplate().retrieveHashes[0]
            );
        }
    }

    function version() 
        virtual override(IWitOracleRequest, IWitOracleRequestTemplate)
        public view
        returns (string memory)
    {
        return IWitAppliance(address(this)).class();
    }


    /// ===============================================================================================================
    /// --- IWitOracleRequestFactory implementation ----------------------------------------------------------------------

    function buildWitOracleRequest(
            bytes32[] calldata _retrieveHashes,
            Witnet.RadonReducer calldata _aggregateReducer,
            Witnet.RadonReducer calldata _tallyReducer
        )
        virtual override external
        onlyOnFactory
        returns (IWitOracleRequest)
    {
        return __buildWitOracleRequest(
            _getWitOracleRadonRegistry().verifyRadonRequest(
                _retrieveHashes,
                _aggregateReducer,
                _tallyReducer
            )
        );
    }

    function buildWitOracleRequestModal(
            bytes32 _baseRetrieveHash,
            string[][] calldata _retrieveArgsValues,
            Witnet.RadonFilter[] calldata _tallySlashingFiltres
        )
        virtual override external
        onlyOnFactory
        returns (IWitOracleRequest)
    {
        bytes32[] memory _retrieveHashes = new bytes32[](_retrieveArgsValues.length);
        for (uint _ix = 0; _ix < _retrieveHashes.length; _ix ++) {
            _retrieveHashes[_ix] = _baseRetrieveHash;
        }
        return __buildWitOracleRequest(
            _getWitOracleRadonRegistry().verifyRadonRequest(
                _retrieveHashes,
                _retrieveArgsValues,
                Witnet.RadonReducer({ opcode: Witnet.RadonReduceOpcodes.Mode, filters: new Witnet.RadonFilter[](0) }),
                Witnet.RadonReducer({ opcode: Witnet.RadonReduceOpcodes.Mode, filters: _tallySlashingFiltres })
            )
        );
    }
    
    function buildWitOracleRequestTemplate(
            bytes32[] calldata _retrieveHashes,
            Witnet.RadonReducer calldata _aggregate,
            Witnet.RadonReducer calldata _tally
        )
        virtual override external
        onlyOnFactory
        returns (IWitOracleRequestTemplate)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();

        // Check input retrievals:
        _require(
            _checkParameterizedRadonRetrievals(_registry, _retrieveHashes),
            "non-parameterized retrievals"
        );

        return __buildWitOracleRequestTemplate(
            _retrieveHashes, 
            bytes16(_registry.verifyRadonReducer(_aggregate)),
            bytes16(_registry.verifyRadonReducer(_tally))
        );
    }

    function buildWitOracleRequestTemplateModal(
            bytes32 _baseRetrieveHash,
            string[] calldata _lastArgValues,
            Witnet.RadonFilter[] calldata _tallySlashingFilters
        ) 
        virtual override external
        returns (IWitOracleRequestTemplate)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();

        // spawn retrievals by repeatedly setting different values to the last parameter
        // of given retrieval:
        bytes32[] memory _retrieveHashes = new bytes32[](_lastArgValues.length);
        for (uint _ix = 0; _ix < _retrieveHashes.length; _ix ++) {
            _retrieveHashes[_ix] = _registry.verifyRadonRetrieval(
                _baseRetrieveHash,
                _lastArgValues[_ix]
            );
        }
        return __buildWitOracleRequestTemplate(
            _retrieveHashes,
            bytes16(_registry.verifyRadonReducer(
                Witnet.RadonReducer({ 
                    opcode: Witnet.RadonReduceOpcodes.Mode, 
                    filters: new Witnet.RadonFilter[](0) 
                })
            )),
            bytes16(_registry.verifyRadonReducer(
                Witnet.RadonReducer({ 
                    opcode: Witnet.RadonReduceOpcodes.Mode, 
                    filters: _tallySlashingFilters 
                })
            ))
        );
    }

    function verifyRadonRetrieval(
            Witnet.RadonRetrievalMethods _requestMethod,
            string calldata _requestURL,
            string calldata _requestBody,
            string[2][] calldata _requestHeaders,
            bytes calldata _requestRadonScript
        )
        virtual override external
        onlyOnFactory
        returns (bytes32 _retrievalHash)
    {
        return _getWitOracleRadonRegistry().verifyRadonRetrieval(
            _requestMethod,
            _requestURL,
            _requestBody,
            _requestHeaders,
            _requestRadonScript
        );
    }


    /// ===============================================================================================================
    /// --- IWitOracleRequestTemplate implementation ---------------------------------------------------------------------

    function buildWitOracleRequest(string[][] calldata _retrieveArgsValues)
        override external
        onlyOnTemplates
        returns (IWitOracleRequest)
    {
        // Verify Radon Request using template's retrieve hashes, aggregate and tally reducers, 
        // and given args:
        WitOracleRequestTemplateStorage storage __template = __witOracleRequestTemplate();
        bytes32 _radHash = _getWitOracleRadonRegistry().verifyRadonRequest(
            __template.retrieveHashes,
            _retrieveArgsValues,
            bytes32(__template.aggregateReduceHash),
            bytes32(__template.tallyReduceHash)    
        );

        return __buildWitOracleRequest(_radHash);
    }

    function buildWitOracleRequest(string calldata _singleArgValue)
        override external
        onlyOnTemplates
        returns (IWitOracleRequest)
    {
        return __buildWitOracleRequest(
            __verifyRadonRequestFromTemplate(_singleArgValue)
        );
    }

    function getArgsCount()
        override external view
        onlyOnTemplates
        returns (uint256[] memory _argsCount)
    {
        
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();
        _argsCount = new uint256[](__witOracleRequestTemplate().retrieveHashes.length);
        for (uint _ix = 0; _ix < _argsCount.length; _ix ++) {
            _argsCount[_ix] = _registry.lookupRadonRetrievalArgsCount(
                __witOracleRequestTemplate().retrieveHashes[_ix]
            );
        }
    }

    function verifyRadonRequest(string[][] calldata _retrieveArgsValues)
        override external
        onlyOnTemplates
        returns (bytes32)
    {
        return _getWitOracleRadonRegistry().verifyRadonRequest(
            __witOracleRequestTemplate().retrieveHashes,
            _retrieveArgsValues,
            bytes32(__witOracleRequestTemplate().aggregateReduceHash),
            bytes32(__witOracleRequestTemplate().tallyReduceHash)
        );
    }

    function verifyRadonRequest(string calldata _singleArgValue)
        override external
        onlyOnTemplates
        returns (bytes32)
    {
        return __verifyRadonRequestFromTemplate(_singleArgValue);
    }

    /// ===============================================================================================================
    /// --- IWitOracleRequest implementation -----------------------------------------------------------------------------

    function bytecode()
        override external view
        onlyOnRequests
        returns (bytes memory)
    {
        return _getWitOracleRadonRegistry().bytecodeOf(
            __witOracleRequest().radHash
        );
    }

    function radHash()
        override external view
        onlyOnRequests
        returns (bytes32)
    {
        return __witOracleRequest().radHash;
    }


    /// ===============================================================================================================
    /// --- Internal methods ------------------------------------------------------------------------------------------

    function __buildWitOracleRequest(bytes32 _radHash)
        virtual internal
        returns (IWitOracleRequest)
    {   
        // Determine request's minimal-proxy counter-factual salt and address:
        (address _requestAddr, bytes32 _requestSalt) = _determineWitOracleRequestAddressAndSalt(_radHash);

        // Create and initialize counter-factual request just once:
        if (_requestAddr.code.length == 0) {
            _requestAddr = WitOracleRequestFactoryBase(_cloneDeterministic(_requestSalt))
                .initializeWitOracleRequest(
                    _radHash
                );
        }

        // Emit event even when building same request more than once
        emit WitOracleRequestBuilt(_requestAddr);
        return IWitOracleRequest(_requestAddr);
    }

    function __buildWitOracleRequestTemplate(
            bytes32[] memory _retrieveHashes,
            bytes16 _aggregateReducerHash,
            bytes16 _tallyReducerHash
        )
        virtual internal
        returns (IWitOracleRequestTemplate)
    {
        // Determine template's minimal-proxy counter-factual salt and address:
        (address _templateAddr, bytes32 _templateSalt) = _determineWitOracleRequestTemplateAddressAndSalt(
            _retrieveHashes,
            _aggregateReducerHash,
            _tallyReducerHash
        );
        
        // Create and initialize counter-factual template just once:
        if (_templateAddr.code.length == 0) {
            _templateAddr = address(
                WitOracleRequestFactoryBase(_cloneDeterministic(_templateSalt))
                    .initializeWitOracleRequestTemplate(
                        _retrieveHashes,
                        _aggregateReducerHash,
                        _tallyReducerHash
                    )
            );
        }

        // Emit event even when building same template more than one
        emit WitOracleRequestTemplateBuilt(_templateAddr);
        return IWitOracleRequestTemplate(_templateAddr);
    }
 
    function _checkParameterizedRadonRetrievals(WitOracleRadonRegistry _registry, bytes32[] calldata _retrieveHashes) 
        internal view returns (bool _parameterized)
    {
        Witnet.RadonDataTypes _resultDataType;
        for (uint _ix = 0; _ix < _retrieveHashes.length; _ix ++) {
            bytes32 _retrievalHash = _retrieveHashes[_ix];
            if (_ix == 0) {
                _resultDataType = _registry.lookupRadonRetrievalResultDataType(_retrievalHash);
            } else {
                _require(
                    _resultDataType == _registry.lookupRadonRetrievalResultDataType(_retrievalHash),
                    "mistmaching retrievals"
                );
            }
            if (!_parameterized) {
                _parameterized = _registry.lookupRadonRetrievalArgsCount(_retrievalHash) > 0;
            }
        }
    }

    function _determineWitOracleRequestAddressAndSalt(bytes32 _radHash)
        virtual internal view
        returns (address, bytes32)
    {
        bytes32 _salt = keccak256(
            abi.encodePacked(
                _radHash, 
                class()
            )
        );
        return (
            address(uint160(uint256(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    _salt,
                    keccak256(_cloneBytecode())
                )
            )))), _salt
        );
    }

    function _determineWitOracleRequestTemplateAddressAndSalt(
            bytes32[] memory _retrieveHashes,
            bytes16 _aggregateReducerHash,
            bytes16 _tallyReducerHash
        )
        virtual internal view
        returns (address, bytes32)
    {
        bytes32 _salt = keccak256(
            // As to avoid template address collisions from:
            abi.encodePacked( 
                // - different factory implementation class
                class(),
                // - different templates params:
                _retrieveHashes,
                _aggregateReducerHash,
                _tallyReducerHash
            )
        );
        return (
            address(uint160(uint256(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    _salt,
                    keccak256(_cloneBytecode())
                )
            )))), _salt
        );
    }

    function __verifyRadonRequestFromTemplate(string calldata _singleArgValue)
        virtual internal
        returns (bytes32)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();
        WitOracleRequestTemplateStorage storage __template = __witOracleRequestTemplate();
        bytes32[] memory _retrieveHashes = new bytes32[](__template.retrieveHashes.length);
        for (uint _ix = 0; _ix < _retrieveHashes.length; _ix ++) {
            _retrieveHashes[_ix] = _registry.verifyRadonRetrieval(
                __template.retrieveHashes[_ix],
                _singleArgValue
            );
        }
        return _registry.verifyRadonRequest(
            _retrieveHashes,
            bytes32(__template.aggregateReduceHash),
            bytes32(__template.tallyReduceHash)
        );
    }
}
