// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../data/WitnetRequestFactoryData.sol";
import "../impls/WitnetUpgradableBase.sol";
import "../patterns/Clonable.sol";

contract WitnetRequestFactory
    is
        Clonable,
        IWitnetRequestFactory,
        WitnetRequest,
        WitnetRequestFactoryData,
        WitnetUpgradableBase        
{
    using ERC165Checker for address;

    /// @notice Reference to Witnet Data Requests Bytecode Registry
    IWitnetBytecodes immutable public override registry;

    modifier onlyDelegateCalls override(Clonable, Upgradeable) {
        require(
            address(this) != _BASE,
            "WitnetRequestFactory: not a delegate call"
        );
        _;
    }

    modifier onlyOnFactory {
        require(
            address(this) == __proxy(),
            "WitnetRequestFactory: not the factory"
        );
        _;
    }

    modifier onlyOnTemplates {
        require(
            __witnetRequestTemplate().tally != bytes32(0),
            "WitnetRequestFactory: not a WitnetRequestTemplate"
        );
        _;
    }

    modifier securedRequest {
        require(
            __witnetRequest().slaHash != bytes32(0),
            "WitnetRequest: unsecured"
        );
        _;
    }

    constructor(
            IWitnetBytecodes _registry,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.requests.factory"
        )
    {
        require(
            address(_registry).supportsInterface(type(IWitnetBytecodes).interfaceId),
            "WitnetRequestFactory: uncompliant registry"
        );
        registry = _registry;
        // let logic contract be used as a factory, while avoiding further initializations:
        __proxiable().proxy = address(this);
        __proxiable().implementation = address(this);
        __witnetRequestFactory().owner = address(0);
    }

    function initializeWitnetRequestTemplate(
            bytes32[] calldata _retrievalsIds,
            bytes32 _aggregatorId,
            bytes32 _tallyId,
            uint16  _resultDataMaxSize
        )
        virtual public
        initializer
        returns (WitnetRequestTemplate)
    {
        // check that at least one retrieval is provided
        WitnetV2.RadonDataTypes _resultDataType;
        require(
            _retrievalsIds.length > 0,
            "WitnetRequestTemplate: no retrievals ?"
        );
        // check that all retrievals exist in the registry,
        // and they all return the same data type
        bool _parameterized;
        for (uint _ix = 0; _ix < _retrievalsIds.length; _ix ++) {
            if (_ix == 0) {
                _resultDataType = registry.lookupRadonRetrievalResultDataType(_retrievalsIds[_ix]);
            } else {
                require(
                    _resultDataType == registry.lookupRadonRetrievalResultDataType(_retrievalsIds[_ix]),
                    "WitnetRequestTemplate: mismatching retrievals"
                );
            }
            if (!_parameterized) {
                // check whether at least one of the retrievals is parameterized
                _parameterized = registry.lookupRadonRetrievalArgsCount(_retrievalsIds[_ix]) > 0;
            }
        }
        // check that the aggregator and tally reducers actually exist in the registry
        registry.lookupRadonReducer(_aggregatorId);
        registry.lookupRadonReducer(_tallyId);
        {
            WitnetRequestTemplateSlot storage __data = __witnetRequestTemplate();
            __data.aggregator = _aggregatorId;
            __data.factory = IWitnetRequestFactory(msg.sender);
            __data.parameterized = _parameterized;
            __data.resultDataType = _resultDataType;
            __data.resultDataMaxSize = _resultDataMaxSize;
            __data.retrievals = _retrievalsIds;
            __data.tally = _tallyId;
        }
        return WitnetRequestTemplate(address(this));
    }

    function initializeWitnetRequest(
            bytes32 _radHash,
            string[][] memory _args
        )
        virtual public
        initializer
        returns (WitnetRequest)
    {
        WitnetRequestSlot storage __data = __witnetRequest();
        __data.args = _args;
        __data.radHash = _radHash;
        __data.template = WitnetRequestTemplate(msg.sender);
        return WitnetRequest(address(this));
    }

    function forkWitnetRequest(
            address _curator,
            bytes32 _slaHash
        )
        virtual public
        initializer
        returns (WitnetRequest)
    {
        WitnetRequestSlot storage __data = __witnetRequest();
        WitnetRequest parent = WitnetRequest(msg.sender);
        bytes32 _radHash = parent.radHash();
        __data.args = parent.args();
        __data.curator = _curator;
        __data.radHash = _radHash;
        __data.slaHash = _slaHash;
        __data.template = parent.template();
        return WitnetRequest(address(this));
    }


    /// ===============================================================================================================
    /// --- IWitnetRequestFactory implementation ----------------------------------------------------------------------

    function buildRequestTemplate(
            bytes32[] memory _retrievals,
            bytes32 _aggregator,
            bytes32 _tally,
            uint16  _resultDataMaxSize
        )
        virtual override
        public
        onlyOnFactory
        returns (WitnetRequestTemplate _template)
    {
        bytes32 _salt = keccak256(
            // As to avoid template address collisions from:
            abi.encodePacked( 
                // - different factory major or mid versions:
                _WITNET_UPGRADABLE_VERSION,// TODO: once WitnetRequestTemplate interface is final: bytes4(_WITNET_UPGRADABLE_VERSION),
                // - different templates params:
                _retrievals, 
                _aggregator,
                _tally,
                _resultDataMaxSize
            )
        );
        address _address = address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _salt,
                keccak256(_cloneBytecode())
            )
        ))));
        if (_address.code.length > 0) {
            _template = WitnetRequestTemplate(_address);
        } else {
            _template = WitnetRequestFactory(
                _cloneDeterministic(_salt)
            ).initializeWitnetRequestTemplate(
                _retrievals,
                _aggregator,
                _tally,
                _resultDataMaxSize
            );
            emit WitnetRequestTemplateBuilt(
                _template,
                _template.parameterized()
            );
        }
    }

    function class() 
        virtual override(IWitnetRequestFactory, WitnetRequestTemplate)
        external view
        returns (bytes4)
    {
        if (address(this) == _SELF) {
            return type(Upgradeable).interfaceId;
        } else {
            if (address(this) == __proxy()) {
                return type(IWitnetRequestFactory).interfaceId;
            } else if (__witnetRequest().radHash != bytes32(0)) {
                return type(WitnetRequest).interfaceId;
            } else {
                return type(WitnetRequestTemplate).interfaceId;
            }
        }
    }


    // ================================================================================================================
    // ---Overrides 'IERC165' -----------------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      returns (bool)
    {
        if (__witnetRequest().radHash != bytes32(0)) {
            return (
                _interfaceId == type(IWitnetRequest).interfaceId
                    || _interfaceId == type(WitnetRequest).interfaceId
                    || _interfaceId  == type(WitnetRequestTemplate).interfaceId
            );
        }
        else if (__witnetRequestTemplate().retrievals.length > 0) {
            return (_interfaceId == type(WitnetRequestTemplate).interfaceId);
        }
        else if (address(this) == __proxy()) {
            return (
                _interfaceId == type(IWitnetRequestFactory).interfaceId
                    || super.supportsInterface(_interfaceId)
            );
        }
        else {
            return (_interfaceId == type(Upgradeable).interfaceId);
        }
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
        public view
        virtual override
        returns (address)
    {
        return __witnetRequestFactory().owner;
    }

    /// @notice Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        public
        virtual override
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
    function initialize(bytes memory) 
        virtual override
        public
        onlyDelegateCalls
    {
        // WitnetRequest or WitnetRequestTemplate instances would already be initialized,
        // so only callable from proxies, in practice.

        address _owner = __witnetRequestFactory().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            __witnetRequestFactory().owner = _owner;
        } else {
            // only owner can initialize the proxy
            if (msg.sender != _owner) {
                revert WitnetUpgradableBase.OnlyOwner(_owner);
            }
        }

        if (__proxiable().proxy == address(0)) {
            // first initialization of the proxy
            __proxiable().proxy = address(this);
        }

        if (__proxiable().implementation != address(0)) {
            // same implementation cannot be initialized more than once:
            if(__proxiable().implementation == base()) {
                revert WitnetUpgradableBase.AlreadyUpgraded(base());
            }
        }        
        __proxiable().implementation = base();

        emit Upgraded(msg.sender, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = __witnetRequestFactory().owner;
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }


    // ================================================================================================================
    /// --- Clonable implementation and override ----------------------------------------------------------------------

    /// @notice Tells whether a WitnetRequest or a WitnetRequestTemplate has been properly initialized.
    /// @dev True only on WitnetRequest instances with some Radon SLA set.
    function initialized()
        virtual override(Clonable)
        public view
        returns (bool)
    {
        return (
            __witnetRequestTemplate().tally != bytes32(0)
                || __witnetRequest().radHash != bytes32(0)
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
    /// --- IWitnetRequest implementation -----------------------------------------------------------------------------

    function bytecode()
        override
        external view
        securedRequest
        returns (bytes memory)
    {
        return registry.bytecodeOf(
            __witnetRequest().radHash,
            __witnetRequest().slaHash
        );
    }

    function hash()
        override
        external view
        securedRequest
        returns (bytes32)
    {
        return sha256(abi.encodePacked(
            __witnetRequest().radHash,
            __witnetRequest().slaHash
        ));
    }

    /// ===============================================================================================================
    /// --- WitnetRequest implementation ------------------------------------------------------------------------------

    function curator()
        override 
        external view
        onlyDelegateCalls
        returns (address)
    {
        return __witnetRequest().curator;
    }

    function secured()
        override
        external view
        onlyDelegateCalls
        returns (bool)
    {
        return __witnetRequest().slaHash != bytes32(0);
    }

    function template()
        override
        external view
        onlyDelegateCalls
        returns (WitnetRequestTemplate)
    {
        return __witnetRequest().template;
    }

    function args()
        override
        external view
        onlyDelegateCalls
        returns (string[][] memory)
    {
        return __witnetRequest().args;
    }

    function radHash()
        override
        external view
        onlyDelegateCalls
        returns (bytes32)
    {
        return __witnetRequest().radHash;
    }

    function slaHash() 
        override
        external view
        onlyDelegateCalls
        returns (bytes32)
    {
        return __witnetRequest().slaHash;
    }

    function getRadonSLA()
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonSLA memory)
    {
        return registry.lookupRadonSLA(
            __witnetRequest().slaHash
        );
    }

    function settleRadonSLA(WitnetV2.RadonSLA memory _sla)
        virtual override
        external
        onlyDelegateCalls
        returns (WitnetRequest _settled)
    {
        WitnetRequestSlot storage __data = __witnetRequest();
        WitnetRequestTemplate _template = __witnetRequest().template;
        require(
            address(_template) != address(0),
            "WitnetRequestFactory: not a WitnetRequest"
        );
        bytes32 _slaHash = registry.verifyRadonSLA(_sla);
        if (_slaHash != __data.slaHash) {
            if (msg.sender == __witnetRequest().curator) {
                __data.slaHash = _slaHash;
                _settled = WitnetRequest(address(this));
            } else {
                (address _address, bytes32 _salt) = _determineAddress(_slaHash);
                if (_address.code.length > 0) {
                    _settled = WitnetRequest(_address);
                } else {
                    _settled = WitnetRequestFactory(_cloneDeterministic(_salt))
                        .forkWitnetRequest(
                            msg.sender,
                            _slaHash
                        )
                    ;
                }
            }
        } else {
            _settled = WitnetRequest(address(this));
        }
        emit WitnetRequestSettled(_settled, __data.radHash, _slaHash);
    }

    function version() 
        virtual override(WitnetRequestTemplate, WitnetUpgradableBase)
        public view
        returns (string memory)
    {
        return WitnetUpgradableBase.version();
    }


    /// ===============================================================================================================
    /// --- WitnetRequestTemplate implementation ----------------------------------------------------------------------

    function factory()
        override
        external view
        onlyDelegateCalls
        returns (IWitnetRequestFactory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.factory();
        } else {
            return __witnetRequestTemplate().factory;
        }
    }

    function aggregator()
        override
        external view
        onlyDelegateCalls
        returns (bytes32)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.aggregator();
        } else {
            return __witnetRequestTemplate().aggregator;
        }
    }

    function parameterized()
        override
        external view
        onlyDelegateCalls
        returns (bool)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.parameterized();
        } else {
            return __witnetRequestTemplate().parameterized;
        }
    }

    function resultDataMaxSize()
        override
        external view
        onlyDelegateCalls
        returns (uint16)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.resultDataMaxSize();
        } else {
            return __witnetRequestTemplate().resultDataMaxSize;
        }
    }

    function resultDataType() 
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonDataTypes)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.resultDataType();
        } else {
            return __witnetRequestTemplate().resultDataType;
        }
    }

    function retrievals()
        override
        external view
        onlyDelegateCalls
        returns (bytes32[] memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.retrievals();
        } else {
            return __witnetRequestTemplate().retrievals;
        }

    }

    function tally()
        override
        external view
        onlyDelegateCalls
        returns (bytes32)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.tally();
        } else {
            return __witnetRequestTemplate().tally;
        }
    }

    function getRadonAggregator()
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonReducer memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getRadonAggregator();
        } else {
            return registry.lookupRadonReducer(
                __witnetRequestTemplate().aggregator
            );
        }
    }

    function getRadonRetrievalByIndex(uint256 _index) 
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonRetrieval memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getRadonRetrievalByIndex(_index);
        } else {
            require(
                _index < __witnetRequestTemplate().retrievals.length,
                "WitnetRequestTemplate: out of range"
            );
            return registry.lookupRadonRetrieval(
                __witnetRequestTemplate().retrievals[_index]
            );
        }
    }

    function getRadonRetrievalsCount() 
        override
        external view
        onlyDelegateCalls
        returns (uint256)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getRadonRetrievalsCount();
        } else {
            return __witnetRequestTemplate().retrievals.length;
        }
    }

    function getRadonTally()
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonReducer memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getRadonTally();
        } else {
            return registry.lookupRadonReducer(
                __witnetRequestTemplate().tally
            );
        }
    }

    function buildRequest(string[][] memory _args)
        virtual override
        public
        onlyDelegateCalls
        returns (WitnetRequest _request)
    {
        // if called on a WitnetRequest instance:
        if (address(__witnetRequest().template) != address(0)) {
            // ...surrogate to request's template
            return __witnetRequest().template.buildRequest(_args);
        }
        WitnetRequestTemplateSlot storage __data = __witnetRequestTemplate();
        bytes32 _radHash = registry.verifyRadonRequest(
            __data.retrievals,
            __data.aggregator,
            __data.tally,
            __data.resultDataMaxSize,
            _args
        );
        // address of unsecured requests (i.e. no slaHash, no curator) built out of a template,
        // will be determined by the template's address and the request's radHash:
        (address _address, bytes32 _salt) = _determineAddress(_radHash);
        if (_address.code.length > 0) {
            _request = WitnetRequest(_address);
        } else {
            _request = WitnetRequestFactory(_cloneDeterministic(_salt))
                .initializeWitnetRequest(
                    _radHash,
                    _args
                );
        }
        emit WitnetRequestBuilt(_request, _radHash, _args);
    }

    function verifyRadonRequest(string[][] memory _args)
        virtual override
        public
        onlyDelegateCalls
        returns (bytes32 _radHash)
    {
        // if called on a WitnetRequest instance:
        if (address(__witnetRequest().template) != address(0)) {
            // ...surrogate to request's template
            return __witnetRequest().template.verifyRadonRequest(_args);
        }
        WitnetRequestTemplateSlot storage __data = __witnetRequestTemplate();
        _radHash = registry.verifyRadonRequest(
            __data.retrievals,
            __data.aggregator,
            __data.tally,
            __data.resultDataMaxSize,
            _args
        );
    }

    function _determineAddress(bytes32 _hash)
        internal view
        returns (address, bytes32)
    {
        bytes32 _salt = keccak256(abi.encodePacked(_hash, bytes4(_WITNET_UPGRADABLE_VERSION)));
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