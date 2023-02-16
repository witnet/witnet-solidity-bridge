// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../data/WitnetRequestFactoryData.sol";
import "../impls/WitnetUpgradableBase.sol";
import "../interfaces/V2/IWitnetBytecodes.sol";
import "../patterns/Clonable.sol";
import "../requests/WitnetRequestTemplate.sol";

interface IWitnetRequestFactory {
    event WitnetRequestTemplateBuilt(WitnetRequestTemplate template);    
    function build(
            bytes32[] memory sourcesIds,
            bytes32 aggregatorId,
            bytes32 tallyId,
            uint16  resultDataMaxSize
        ) external returns (WitnetRequestTemplate _template);
}

contract WitnetRequestFactory
    is
        Clonable,
        IWitnetRequestFactory,
        WitnetRequest,
        WitnetRequestFactoryData,
        WitnetRequestTemplate,
        WitnetUpgradableBase
{
    using ERC165Checker for address;

    /// @notice Reference to Witnet Data Requests Bytecode Registry
    IWitnetBytecodes immutable public registry;

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
            "WitnetRequestFactory: not a factory"
        );
        _;
    }

    modifier onlyOnTemplates {
        require(
            __witnetRequestTemplate().tallyHash != bytes32(0),
            "WitnetRequestFactory: not a template"
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
    }


    /// ===============================================================================================================
    /// --- IWitnetRequestFactory implementation ----------------------------------------------------------------------

    function build(
            bytes32[] memory sourcesIds,
            bytes32 aggregatorId,
            bytes32 tallyId,
            uint16  resultDataMaxSize
        )
        virtual override
        external
        onlyOnFactory
        returns (WitnetRequestTemplate _template)
    {
        _template = WitnetRequestFactory(_cloneDeterministic(
            keccak256(abi.encodePacked(
                sourcesIds,
                aggregatorId,
                tallyId,
                resultDataMaxSize
            ))
        )).initializeWitnetRequestTemplate(
            sourcesIds,
            aggregatorId,
            tallyId,
            resultDataMaxSize
        );
        emit WitnetRequestTemplateBuilt(_template);
    }

    function initializeWitnetRequestTemplate(
            bytes32[] calldata _sources,
            bytes32 _aggregatorId,
            bytes32 _tallyId,
            uint16  _resultDataMaxSize
        )
        virtual public
        initializer
        returns (WitnetRequestTemplate)
    {
        WitnetV2.RadonDataTypes _resultDataType;
        require(_sources.length > 0, "WitnetRequestTemplate: no sources");
        // check all sources return the same data types
        for (uint _ix = 0; _ix < _sources.length; _ix ++) {
            if (_ix == 0) {
                _resultDataType = registry.lookupDataSourceResultDataType(_sources[_ix]);
            } else {
                require(
                    _resultDataType == registry.lookupDataSourceResultDataType(_sources[_ix]),
                    "WitnetRequestTemplate: mismatching sources"
                );
            }
        }
        // revert if the aggregator reducer is unknown
        registry.lookupRadonReducer(_aggregatorId);
        // revert if the tally reducer is unknown
        registry.lookupRadonReducer(_tallyId);
        {
            WitnetRequestTemplateSlot storage __data = __witnetRequestTemplate();
            __data.sources = _sources;
            __data.aggregatorHash = _aggregatorId;
            __data.tallyHash = _tallyId;
            __data.resultDataType = _resultDataType;
            __data.resultDataMaxSize = _resultDataMaxSize;
        }
        return WitnetRequestTemplate(address(this));
    }
    
    function initializeWitnetRequest(
            string[][] memory _args,
            bytes32 _radHash
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


    // ================================================================================================================
    // ---Overrides 'IERC165' -----------------------------------------------------------------------------------------

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 _interfaceId)
      public view
      virtual override
      returns (bool)
    {
        if (address(this) == _SELF) {
            return (_interfaceId == type(Upgradeable).interfaceId);
        } else {
            if (address(this) == __proxy()) {
                return (
                    _interfaceId == type(IWitnetRequestFactory).interfaceId
                        || super.supportsInterface(_interfaceId)
                );
            } else if (__witnetRequest().radHash != bytes32(0)) {
                return (
                    _interfaceId == type(WitnetRequestTemplate).interfaceId
                        || _interfaceId == type(WitnetRequest).interfaceId
                        || _interfaceId  == type(IWitnetRequest).interfaceId
                );
            } else {
                return (_interfaceId == type(WitnetRequestTemplate).interfaceId);
            }
        }
    }


    // ================================================================================================================
    // --- Overrides 'Ownable2Step' -----------------------------------------------------------------------------------

    /// @notice Returns the address of the pending owner.
    function pendingOwner()
        public view
        virtual override
        onlyOnFactory
        returns (address)
    {
        return __witnetRequestFactory().pendingOwner;
    }

    /// @notice Returns the address of the current owner.
    function owner()
        public view
        virtual override
        onlyOnFactory
        returns (address)
    {
        return __witnetRequestFactory().owner;
    }

    /// @notice Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    function transferOwnership(address _newOwner)
        public
        virtual override
        onlyOnFactory
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
        initializer 
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

    /// @notice Tells whether a WitnetRequest instance has been fully initialized.
    /// @dev True only on WitnetRequest instances with some Radon SLA set.
    function initialized()
        virtual override(Clonable, WitnetRequest)
        public view
        returns (bool)
    {
        return __witnetRequest().slaHash != bytes32(0);
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

    function bytecode() override external view returns (bytes memory) {
        return __witnetRequest().bytecode;
    }

    function hash() override external view returns (bytes32) {
        return __witnetRequest().hash;
    }


    /// ===============================================================================================================
    /// --- WitnetRequest implementation ------------------------------------------------------------------------------

    function args()
        override
        external view
        onlyDelegateCalls
        returns (string[][] memory)
    {
        return __witnetRequest().args;
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

    function template()
        override
        external view
        onlyDelegateCalls
        returns (WitnetRequestTemplate)
    {
        return __witnetRequest().template;
    }

    function modifySLA(WitnetV2.RadonSLA memory _sla)
        virtual override
        external
        onlyDelegateCalls
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        require(
            address(_template) != address(0),
            "WitnetRequestFactory: not a request"
        );
        bytes32 _slaHash = registry.verifyRadonSLA(_sla);
        WitnetRequestSlot storage __data = __witnetRequest();
        bytes memory _bytecode = registry.bytecodeOf(__data.radHash, _slaHash);
        __data.bytecode = _bytecode;
        __data.hash = Witnet.hash(_bytecode);
        __data.slaHash = _slaHash;
        emit WitnetRequestSettled(_sla);
    }


    /// ===============================================================================================================
    /// --- WitnetRequestTemplate implementation ----------------------------------------------------------------------

    function getDataSources()
        override
        external view
        onlyDelegateCalls
        returns (bytes32[] memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getDataSources();
        } else {
            return __witnetRequestTemplate().sources;
        }

    }

    function getDataSourcesArgsCount()
        override
        external view
        onlyDelegateCalls
        returns (uint8[] memory)
    {
        revert("WitnetRequestFactory: not yet implemented");
    }

    function getDataSourcesCount() 
        override
        external view
        onlyDelegateCalls
        returns (uint256)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getDataSourcesCount();
        } else {
            return __witnetRequestTemplate().sources.length;
        }
    }

    function getRadonAggregatorHash()
        override
        external view
        onlyDelegateCalls
        returns (bytes32)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getRadonAggregatorHash();
        } else {
            return __witnetRequestTemplate().aggregatorHash;
        }
    }
    
    function getRadonTallyHash()
        override
        external view
        onlyDelegateCalls
        returns (bytes32)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getRadonTallyHash();
        } else {
            return __witnetRequestTemplate().tallyHash;
        }
    }
    
    function getResultDataMaxSize()
        override
        external view
        onlyDelegateCalls
        returns (uint16)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getResultDataMaxSize();
        } else {
            return __witnetRequestTemplate().resultDataMaxSize;
        }
    }

    function getResultDataType() 
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonDataTypes)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.getResultDataType();
        } else {
            return __witnetRequestTemplate().resultDataType;
        }
    }

    function lookupDataSourceByIndex(uint256 _index) 
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.DataSource memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.lookupDataSourceByIndex(_index);
        } else {
            require(
                _index < __witnetRequestTemplate().sources.length,
                "WitnetRequestTemplate: out of range"
            );
            return registry.lookupDataSource(
                __witnetRequestTemplate().sources[_index]
            );
        }
    }

    function lookupRadonAggregator()
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonReducer memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.lookupRadonAggregator();
        } else {
            return registry.lookupRadonReducer(
                __witnetRequestTemplate().aggregatorHash
            );
        }
    }

    function lookupRadonTally()
        override
        external view
        onlyDelegateCalls
        returns (WitnetV2.RadonReducer memory)
    {
        WitnetRequestTemplate _template = __witnetRequest().template;
        if (address(_template) != address(0)) {
            return _template.lookupRadonTally();
        } else {
            return registry.lookupRadonReducer(
                __witnetRequestTemplate().tallyHash
            );
        }
    }

    function settleArgs(string[][] memory _args)
        virtual override
        external
        onlyOnTemplates
        returns (WitnetRequest request)
    {
        WitnetRequestTemplateSlot storage __data = __witnetRequestTemplate();
        bytes32 _radHash = registry.verifyRadonRetrieval(
            __data.resultDataType,
            __data.resultDataMaxSize,
            __data.sources,
            _args,
            __data.aggregatorHash,
            __data.tallyHash
        );
        request = WitnetRequestFactory(
            _cloneDeterministic(_radHash)
        ).initializeWitnetRequest(
            _args,
            _radHash
        );
        emit WitnetRequestTemplateSettled(request, _radHash, _args);
    }
}