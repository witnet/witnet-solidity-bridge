// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetUpgradableBase.sol";
import "../../WitOracleRadonRegistry.sol";
import "../../WitOracleRequestFactory.sol";
import "../../data/WitOracleRequestFactoryData.sol";
import "../../interfaces/IWitOracleRadonRegistryLegacy.sol";
import "../../patterns/Clonable.sol";

contract WitOracleRequestFactoryDefault
    is
        Clonable,
        WitOracleRequest,
        WitOracleRequestFactory,
        WitOracleRequestFactoryData,
        WitOracleRequestTemplate,
        WitnetUpgradableBase        
{
     /// @notice Reference to the Witnet Request Board that all templates built out from this factory will refer to.
    WitOracle immutable public override witnet;

    modifier notOnFactory {
        _require(
            address(this) != __proxy()
                && address(this) != base(),
            "not on factory"
        ); _;
    }

    modifier onlyDelegateCalls override(Clonable, Upgradeable) {
        _require(
            address(this) != _BASE,
            "not a delegate call"
        ); _;
    }

    modifier onlyOnFactory {
        _require(
            address(this) == __proxy()
                || address(this) == base(),
            "not the factory"
        ); _;
    }

    modifier onlyOnRequests {
        _require(
            __witnetRequest().radHash != bytes32(0),
            "not a request"
        ); _;
    }

    modifier onlyOnTemplates {
        _require(
            __witnetRequestTemplate().tallyReduceHash != bytes32(0),
            "not a template"
        ); _;
    }

    constructor(
            WitOracle _witnet,
            bool _upgradable,
            bytes32 _versionTag
        )
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.requests.factory"
        )
    {
        witnet = _witnet;
        // let logic contract be used as a factory, while avoiding further initializations:
        __proxiable().proxy = address(this);
        __proxiable().implementation = address(this);
        __witnetRequestFactory().owner = address(0);
    }

    function _getWitOracleRadonRegistry() virtual internal view returns (WitOracleRadonRegistry) {
        return witnet.registry();
    }

    function initializeWitOracleRequest(bytes32 _radHash)
        virtual public initializer
        returns (address)
    {
        _require(_radHash != bytes32(0), "no rad hash?");
        __witnetRequest().radHash = _radHash;   
        return address(this);
    }

    function initializeWitOracleRequestTemplate(
            bytes32[] calldata _retrieveHashes,
            bytes16 _aggregateReduceHash,
            bytes16 _tallyReduceHash
        )
        virtual public initializer
        returns (address)
    {   
        _require(_retrieveHashes.length > 0, "no retrievals?");
        _require(_aggregateReduceHash != bytes16(0), "no aggregate reducer?");
        _require(_tallyReduceHash != bytes16(0), "no tally reducer?");

        WitOracleRequestTemplateStorage storage __data = __witnetRequestTemplate();
        __data.retrieveHashes = _retrieveHashes;
        __data.aggregateReduceHash = _aggregateReduceHash;
        __data.tallyReduceHash = _tallyReduceHash;
        return address(this);
    }


    // ================================================================================================================
    // --- Overrides 'Ownable2Step' -----------------------------------------------------------------------------------

    /// @notice Returns the address of the pending owner.
    function pendingOwner()
        public view
        virtual override
        returns (address)
    {
        return __witnetRequestFactory().pendingOwner;
    }

    /// @notice Returns the address of the current owner.
    function owner()
        virtual override
        public view
        returns (address)
    {
        return __witnetRequestFactory().owner;
    }

    /// @notice Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        virtual override public
        onlyOwner
    {
        __witnetRequestFactory().pendingOwner = _newOwner;
        emit OwnershipTransferStarted(owner(), _newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`_newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    function _transferOwnership(address _newOwner)
        internal
        virtual override
    {
        delete __witnetRequestFactory().pendingOwner;
        address _oldOwner = owner();
        if (_newOwner != _oldOwner) {
            __witnetRequestFactory().owner = _newOwner;
            emit OwnershipTransferred(_oldOwner, _newOwner);
        }
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData) 
        virtual override public
        onlyDelegateCalls
    {
        _require(!initialized(), "already initialized");
        
        // Trying to intialize an upgradable factory instance...
        {
            address _owner = __witnetRequestFactory().owner;
            if (_owner == address(0)) {
                // Upon first initialization of an upgradable factory,
                // set owner from the one specified in _initData
                _owner = abi.decode(_initData, (address));
                __witnetRequestFactory().owner = _owner;
            } else {
                // only the owner can upgrade an upgradable factory
                _require(
                    msg.sender == _owner,
                    "not the owner"
                );
            }

            if (__proxiable().proxy == address(0)) {
                // first initialization of the proxy
                __proxiable().proxy = address(this);
            }
            __proxiable().implementation = base();

            _require(address(witnet).code.length > 0, "inexistent request board");
            _require(witnet.specs() == type(WitOracle).interfaceId, "uncompliant request board");
            
            emit Upgraded(msg.sender, base(), codehash(), version());
        }
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = __witnetRequestFactory().owner;
        return (
            // false if the logic contract is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
                && _owner != address(0)
        );
    }


    // ================================================================================================================
    /// --- Clonable implementation and override ----------------------------------------------------------------------

    /// @notice Tells whether a WitOracleRequest or a WitOracleRequestTemplate has been properly initialized.
    function initialized()
        virtual override(Clonable)
        public view
        returns (bool)
    {
        return (
            __witnetRequestTemplate().tallyReduceHash != bytes16(0)
                || __witnetRequest().radHash != bytes32(0)
                || __implementation() == base()
        );
    }

    /// @notice Contract address to which clones will be re-directed.
    function self()
        virtual override
        public view
        returns (address)
    {
        return (__proxy() != address(0)
            ? __implementation()
            : base()
        );
    }


    /// ===============================================================================================================
    /// --- IWitOracleRequestFactory, IWitOracleRequestTemplate, IWitOracleRequest polymorphic methods -------------------------

    function class()
        virtual override(IWitAppliance, WitnetUpgradableBase)
        public view
        returns (string memory)
    {
        if (__witnetRequest().radHash != bytes32(0)) {
            return type(WitOracleRequest).name;
        } else if (__witnetRequestTemplate().tallyReduceHash != bytes16(0)) {
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
        if (__witnetRequest().radHash != bytes32(0)) {
            return type(WitOracleRequest).interfaceId;
        } else if (__witnetRequestTemplate().tallyReduceHash != bytes16(0)) {
            return type(WitOracleRequestTemplate).interfaceId;
        } else {
            return type(WitOracleRequestFactory).interfaceId;
        }
    }

    
    /// ===============================================================================================================
    /// --- IWitOracleRequestTemplate, IWitOracleRequest polymorphic methods ------------------------------------------------

    function getRadonReducers()
        virtual override (IWitOracleRequest, IWitOracleRequestTemplate)
        external view
        notOnFactory
        returns (Witnet.RadonReducer memory, Witnet.RadonReducer memory)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();
        if (__witnetRequest().radHash != bytes32(0)) {
            return (
                _registry.lookupRadonRequestAggregator(__witnetRequest().radHash),
                _registry.lookupRadonRequestTally(__witnetRequest().radHash)
            );
        } else {
            return (
                _registry.lookupRadonReducer(__witnetRequestTemplate().aggregateReduceHash),
                _registry.lookupRadonReducer(__witnetRequestTemplate().tallyReduceHash)
            );
        }
    }

    function getRadonRetrievalByIndex(uint256 _index)
        virtual override (IWitOracleRequest, IWitOracleRequestTemplate)
        external view 
        notOnFactory
        returns (Witnet.RadonRetrieval memory)
    {
        if (__witnetRequest().radHash != bytes32(0)) {
            return _getWitOracleRadonRegistry().lookupRadonRequestRetrievalByIndex(
                __witnetRequest().radHash,
                _index
            );
        } else {
            _require(
                _index < __witnetRequestTemplate().retrieveHashes.length, 
                "index out of range"
            );
            return _getWitOracleRadonRegistry().lookupRadonRetrieval(
                __witnetRequestTemplate().retrieveHashes[_index]
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
        if (__witnetRequest().radHash != bytes32(0)) {
            return _registry.lookupRadonRequestRetrievals(
                __witnetRequest().radHash
            );
        } else {
            _retrievals = new Witnet.RadonRetrieval[](__witnetRequestTemplate().retrieveHashes.length);
            for (uint _ix = 0; _ix < _retrievals.length; _ix ++) {
                _retrievals[_ix] = _registry.lookupRadonRetrieval(
                    __witnetRequestTemplate().retrieveHashes[_ix]
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
        if (__witnetRequest().radHash != bytes32(0)) {
            return _getWitOracleRadonRegistry().lookupRadonRequestResultDataType(
                __witnetRequest().radHash
            );
        } else {
            return _getWitOracleRadonRegistry().lookupRadonRetrievalResultDataType(
                __witnetRequestTemplate().retrieveHashes[0]
            );
        }
    }

    function version() 
        virtual override(IWitOracleRequest, IWitOracleRequestTemplate, WitnetUpgradableBase)
        public view
        returns (string memory)
    {
        return WitnetUpgradableBase.version();
    }


    /// ===============================================================================================================
    /// --- IWitOracleRequestFactory implementation ----------------------------------------------------------------------

    function buildWitOracleRequest(
            bytes32[] calldata _retrieveHashes,
            Witnet.RadonReducer calldata _aggregate,
            Witnet.RadonReducer calldata _tally
        )
        virtual override external
        onlyOnFactory
        returns (address)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();

        // TODO: checks and reducers verification should be done by the registry instead ...

        // Check input retrievals:
        _require(
            !_checkParameterizedRadonRetrievals(_registry, _retrieveHashes),
            "parameterized retrievals"
        );

        // Check input reducers:
        bytes16 _aggregateReduceHash = _registry.verifyRadonReducer(_aggregate);
        bytes16 _tallyReduceHash = _registry.verifyRadonReducer(_tally);

        // Verify Radon Request:
        bytes32 _radHash = IWitOracleRadonRegistryLegacy(address(_registry)).verifyRadonRequest(
            _retrieveHashes, 
            bytes32(_aggregateReduceHash),
            bytes32(_tallyReduceHash),
            uint16(0),
            new string[][](0)
        );

        // Determine request's minimal-proxy counter-factual salt and address:
        (address _requestAddr, bytes32 _requestSalt) = _determineWitOracleRequestAddressAndSalt(_radHash);

        // Create and initialize counter-factual request just once:
        if (_requestAddr.code.length == 0) {
            _requestAddr = WitOracleRequestFactoryDefault(_cloneDeterministic(_requestSalt))
                .initializeWitOracleRequest(
                    _radHash
                );
        }

        // Emit event even when building same request more than once
        emit WitOracleRequestBuilt(_requestAddr);
        return _requestAddr;
    }
    
    function buildWitOracleRequestTemplate(
            bytes32[] calldata _retrieveHashes,
            Witnet.RadonReducer calldata _aggregate,
            Witnet.RadonReducer calldata _tally
        )
        virtual override external
        onlyOnFactory
        returns (address)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();

        // Check input retrievals:
        _require(
            _checkParameterizedRadonRetrievals(_registry, _retrieveHashes),
            "non-parameterized retrievals"
        );

        // Check input reducers:
        bytes16 _aggregateReduceHash = _registry.verifyRadonReducer(_aggregate);
        bytes16 _tallyReduceHash = _registry.verifyRadonReducer(_tally);

        // Determine template's minimal-proxy counter-factual salt and address:
        (address _templateAddr, bytes32 _templateSalt) = _determineWitOracleRequestTemplateAddressAndSalt(
            _retrieveHashes,
            _aggregateReduceHash,
            _tallyReduceHash
        );
        
        // Create and initialize counter-factual template just once:
        if (_templateAddr.code.length == 0) {
            _templateAddr = address(
                WitOracleRequestFactoryDefault(_cloneDeterministic(_templateSalt))
                    .initializeWitOracleRequestTemplate(
                        _retrieveHashes,
                        _aggregateReduceHash,
                        _tallyReduceHash
                    )
            );
        }

        // Emit event even when building same template more than one
        emit WitOracleRequestTemplateBuilt(_templateAddr);
        return _templateAddr;
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

    function buildWitOracleRequest(string[][] calldata _retrieveArgs)
        override external
        onlyOnTemplates
        returns (address _request)
    {
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();
        WitOracleRequestTemplateStorage storage __template = __witnetRequestTemplate();

        // Verify Radon Request using template's retrieve hashes, aggregate and tally reducers, 
        // and given args:
        bytes32 _radHash = IWitOracleRadonRegistryLegacy(address(_registry)).verifyRadonRequest(
            __template.retrieveHashes,
            bytes32(__template.aggregateReduceHash),
            bytes32(__template.tallyReduceHash),
            0,
            _retrieveArgs
        );
        
        // Determine request's minimal-proxy counter-factual salt and address:
        (address _requestAddr, bytes32 _requestSalt) = _determineWitOracleRequestAddressAndSalt(_radHash);

        // Create and initialize counter-factual request just once:
        if (_requestAddr.code.length == 0) {
            _requestAddr = WitOracleRequestFactoryDefault(_cloneDeterministic(_requestSalt))
                .initializeWitOracleRequest(
                    _radHash
                );
        }

        // Emit event even when building same request more than once
        emit WitOracleRequestBuilt(_requestAddr);
        return _requestAddr;
    }

    function getArgsCount()
        override external view
        onlyOnTemplates
        returns (uint256[] memory _argsCount)
    {
        
        WitOracleRadonRegistry _registry = _getWitOracleRadonRegistry();
        _argsCount = new uint256[](__witnetRequestTemplate().retrieveHashes.length);
        for (uint _ix = 0; _ix < _argsCount.length; _ix ++) {
            _argsCount[_ix] = _registry.lookupRadonRetrievalArgsCount(
                __witnetRequestTemplate().retrieveHashes[_ix]
            );
        }
    }

    function verifyRadonRequest(string[][] calldata _args)
        override external
        onlyOnTemplates
        returns (bytes32)
    {
        return IWitOracleRadonRegistryLegacy(address(_getWitOracleRadonRegistry())).verifyRadonRequest(
            __witnetRequestTemplate().retrieveHashes,
            bytes32(__witnetRequestTemplate().aggregateReduceHash),
            bytes32(__witnetRequestTemplate().tallyReduceHash),
            0,
            _args
        );
    }

    /// ===============================================================================================================
    /// --- IWitOracleRequest implementation -----------------------------------------------------------------------------

    function bytecode()
        override external view
        onlyOnRequests
        returns (bytes memory)
    {
        return _getWitOracleRadonRegistry().bytecodeOf(
            __witnetRequest().radHash
        );
    }

    function radHash()
        override external view
        onlyOnRequests
        returns (bytes32)
    {
        return __witnetRequest().radHash;
    }


    /// ===============================================================================================================
    /// --- Internal methods ------------------------------------------------------------------------------------------
 
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
                bytes4(_WITNET_UPGRADABLE_VERSION)
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
            bytes32[] calldata _retrieveHashes,
            bytes16 _aggregateReduceHash,
            bytes16 _tallyReduceHash
        )
        virtual internal view
        returns (address, bytes32)
    {
        bytes32 _salt = keccak256(
            // As to avoid template address collisions from:
            abi.encodePacked( 
                // - different factory major or mid versions:
                bytes4(_WITNET_UPGRADABLE_VERSION),
                // - different templates params:
                _retrieveHashes,
                _aggregateReduceHash,
                _tallyReduceHash
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
}