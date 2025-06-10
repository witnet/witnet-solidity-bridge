// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../WitOracleRadonRequestFactory.sol";

import "../../interfaces/IWitOracle.sol";
import "../../interfaces/IWitOracleAppliance.sol";
import "../../interfaces/IWitOracleRadonRequestModal.sol";
import "../../interfaces/IWitOracleRadonRequestTemplate.sol";

import "../../patterns/Clonable.sol";

abstract contract WitOracleRadonRequestFactoryBase
    is
        WitOracleRadonRequestFactory
{
    using Witnet for Witnet.RadonHash;

    /// @notice Reference to the Witnet Request Board that all templates built out from this factory will refer to.
    address immutable public override witOracle;
    
    IWitOracleRadonRegistry immutable internal __witOracleRadonRegistry;
    
    WitOracleRadonRequestModalCloner immutable internal __witOracleRadonRequestModal;
    WitOracleRadonRequestTemplateCloner immutable internal __witOracleRadonRequestTemplate;

    constructor(address _witOracle)
    {
        witOracle = _witOracle;
        _require(
            _witOracle != address(0) && _witOracle.code.length > 0, 
            "inexistent oracle"
        );
        __witOracleRadonRegistry = IWitOracle(witOracle).registry();
        __witOracleRadonRequestModal = new WitOracleRadonRequestModalCloner(_witOracle);
        __witOracleRadonRequestTemplate = new WitOracleRadonRequestTemplateCloner(_witOracle);
    }

    /// ===============================================================================================================
    /// --- Implementation of IWitOracleRadonRequestFactory -----------------------------------------------------------

    function buildRadonRequestModal(
            DataSourceRequest calldata commonDataRequest,
            Witnet.RadonReducer memory crowdAttestationTally
        )
        virtual override
        external 
        returns (IWitOracleRadonRequestModal)
    {
        bytes32 _commonRetrievalHash = __witOracleRadonRegistry.verifyRadonRetrieval(
            commonDataRequest.method,
            "\\0\\",
            commonDataRequest.body,
            commonDataRequest.headers,
            commonDataRequest.script
        );
        bytes16 _crowdAttestationTallyHash = bytes16(__witOracleRadonRegistry.verifyRadonReducer(
            crowdAttestationTally
        ));
        address _modal = __witOracleRadonRequestModal.determineAddress(
            _commonRetrievalHash,
            _crowdAttestationTallyHash
        );
        if (_modal.code.length == 0) {
            __witOracleRadonRequestModal.clone(
                _commonRetrievalHash,
                _crowdAttestationTallyHash
            );
            _checkCloneWasDeployed(_modal);
            emit NewRadonRequestModal(_modal);
        }
        return IWitOracleRadonRequestModal(_modal);
    }

    function buildRadonRequestTemplate(
            bytes32[] memory radonRetrieveHashes,
            Witnet.RadonReducer memory dataSourcesAggregator,
            Witnet.RadonReducer memory crowdAttestationTally
        )
        virtual override
        public
        returns (IWitOracleRadonRequestTemplate)
    {
        bytes16 _dataSourcesAggregatorHash = bytes16(__witOracleRadonRegistry.verifyRadonReducer(dataSourcesAggregator));
        bytes16 _crowdAttestationTallyHash = bytes16(__witOracleRadonRegistry.verifyRadonReducer(crowdAttestationTally));
        address _template = __witOracleRadonRequestTemplate.determineAddress(
            radonRetrieveHashes,
            _dataSourcesAggregatorHash,
            _crowdAttestationTallyHash
        );
        if (_template.code.length == 0) {
            __witOracleRadonRequestTemplate.clone(
                radonRetrieveHashes,
                _dataSourcesAggregatorHash,
                _crowdAttestationTallyHash
            );
            _checkCloneWasDeployed(_template);
            emit NewRadonRequestTemplate(_template);
        }
        return IWitOracleRadonRequestTemplate(_template);
    }

    function buildRadonRequestTemplate(
            DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        virtual override
        external 
        returns (IWitOracleRadonRequestTemplate)
    {
        bytes32[] memory _radonRetrieveHashes = new bytes32[](dataSources.length);
        for (uint _ix; _ix < dataSources.length; ++ _ix) {
            DataSourceRequest memory _request = dataSources[_ix].request;
            _radonRetrieveHashes[_ix] = __witOracleRadonRegistry.verifyRadonRetrieval(
                _request.method,
                dataSources[_ix].url,
                _request.body,
                _request.headers,
                _request.script
            );
        }
        return buildRadonRequestTemplate(
            _radonRetrieveHashes,
            dataSourcesAggregator,
            crowdAttestationTally
        );
    }


    /// ===============================================================================================================
    /// --- Internal virtual methods ----------------------------------------------------------------------------------

    function _checkCloneWasDeployed(address _clone) virtual internal view {
        _require(
            _clone.code.length > 0,
            "cannot clone"
        );
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract WitOracleRadonRequestModalCloner
    is
        Clonable,
        IWitOracleAppliance,
        IWitOracleRadonRequestModal 
{
        function class() virtual override public view  returns (string memory) {
        return type(WitOracleRadonRequestModalCloner).name;
    }

    function specs() virtual override public pure returns (bytes4) {
        return type(IWitOracleRadonRequestModal).interfaceId;
    }

    /// @notice Reference to the Witnet Request Board that all templates built out from this factory will refer to.
    address immutable public override(IWitOracleAppliance, IWitOracleRadonRequestModal) witOracle;

    IWitOracleRadonRegistry internal immutable __witOracleRadonRegistry;
    bytes16 internal immutable __radonAggregateHash;
    
    struct Storage {
        /// @notice  Radon retrieval common to all data providers.
        bytes32 radonRetrieveHash;
        /// @notice Crowd attestation tally.
        bytes16 radonTallyHash;
    }
    Storage private __storage;

    constructor(address _witOracle) {
        _require(_witOracle != address(0) && _witOracle.code.length > 0, "inexistent Wit/Oracle");
        witOracle = _witOracle;
        __witOracleRadonRegistry = IWitOracle(witOracle).registry();
        __radonAggregateHash = bytes16(__witOracleRadonRegistry.verifyRadonReducer(
            Witnet.RadonReducer({
                opcode: Witnet.RadonReduceOpcodes.Mode,
                filters: new Witnet.RadonFilter[](0)
            })
        ));
    }

    function clone(
            bytes32 _commonRetrievalHash, 
            bytes16 _crowdAttestationTallyHash
        ) 
        virtual //override
        external
        returns (IWitOracleRadonRequestModal)
    {
        return WitOracleRadonRequestModalCloner(
            _cloneDeterministic(_determineSaltAndPepper(
                _commonRetrievalHash,
                _crowdAttestationTallyHash
            ))
        ).initialize(
            _commonRetrievalHash,
            _crowdAttestationTallyHash
        );
    }

    function determineAddress(
            bytes32 _commonRetrievalHash,
            bytes16 _crowdAttestationTallyHash
        )
        virtual //override
        external view
        returns (address)
    {
        return address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _determineSaltAndPepper(
                    _commonRetrievalHash,
                    _crowdAttestationTallyHash
                ),
                keccak256(_cloneBytecode())
            )
        ))));
    }

    function initialize(
            bytes32 _commonRetrievalHash,
            bytes16 _crowdAttestationTallyHash
        )
        virtual
        public 
        initializer
        returns (IWitOracleRadonRequestModal)
    {   
        assert(__witOracleRadonRegistry.lookupRadonRetrievalArgsCount(_commonRetrievalHash) >= 1);
        __witOracleRadonRegistry.isVerifiedRadonReducer(_crowdAttestationTallyHash);
        __storage.radonRetrieveHash = _commonRetrievalHash;
        __storage.radonTallyHash = _crowdAttestationTallyHash;
        return IWitOracleRadonRequestModal(address(this));
    }


    // ================================================================================================================
    /// --- Clonable implementation and override ----------------------------------------------------------------------

    /// @notice Tells whether a WitOracleRequest or a WitOracleRequestTemplate has been properly initialized.
    function initialized()
        virtual override(Clonable)
        public view
        returns (bool)
    {
        return __storage.radonRetrieveHash != bytes32(0);
    }


    /// ===============================================================================================================
    /// --- IWitOracleRadonRequestModal -------------------------------------------------------------------------------
    
    function getCrowdAttestationTally()
        virtual override
        external view 
        onlyDelegateCalls
        returns (Witnet.RadonReducer memory)
    {
        return __witOracleRadonRegistry.lookupRadonReducer(
            __storage.radonTallyHash
        );
    }

    function getDataResultType()
        virtual override
        external view 
        onlyDelegateCalls
        returns (Witnet.RadonDataTypes)
    {
        return __witOracleRadonRegistry.lookupRadonRetrievalResultDataType(
            __storage.radonRetrieveHash
        );
    }

    function getDataSourcesAggregator() 
        virtual override
        external view
        onlyDelegateCalls
        returns (Witnet.RadonReducer memory)
    {
        return __witOracleRadonRegistry.lookupRadonReducer(
            __radonAggregateHash
        );
    }

    function getDataSourcesArgsCount()
        virtual override
        external view
        onlyDelegateCalls
        returns (uint8)
    {
        return __witOracleRadonRegistry.lookupRadonRetrievalArgsCount(
            __storage.radonRetrieveHash
        );
    }

    function getRadonModalRetrieval() 
        virtual override
        external view 
        onlyDelegateCalls
        returns (Witnet.RadonRetrieval memory)
    {
        return __witOracleRadonRegistry.lookupRadonRetrieval(
            __storage.radonRetrieveHash
        );
    }

    function verifyRadonRequest(
            string[] calldata commonRetrievalArgs,
            string[] calldata dataProviders
        ) 
        virtual override
        external 
        onlyDelegateCalls
        returns (Witnet.RadonHash)
    {
        // string[] memory _args = new string[][](dataProviders.length);
        // for (uint _ix = 0; _ix < dataProviders.length; ++ _ix) {
        //     _args[_ix] = new string[](commonArgs.length + 1);
        //     _args[_ix][0] = dataProviders[_ix];
        //     for (uint _jx = 0; _jx < commonArgs.length; ++ _jx) {
        //         _args[_ix][_jx + 1] = commonArgs[_jx];   
        //     }
        // }
        return __witOracleRadonRegistry.verifyRadonRequest(
            __storage.radonRetrieveHash,
            commonRetrievalArgs,
            dataProviders,
            __radonAggregateHash,
            __storage.radonTallyHash
        );
    }


    /// ===============================================================================================================
    /// --- Internal methods ------------------------------------------------------------------------------------------

    function _determineSaltAndPepper(
            bytes32 _commonRetrievalHash, 
            bytes16 _crowdAttestationTally
        )
        virtual internal view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                _SELF,
                _commonRetrievalHash,
                _crowdAttestationTally
            )
        );
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
contract WitOracleRadonRequestTemplateCloner
    is
        Clonable,
        IWitOracleAppliance,
        IWitOracleRadonRequestTemplate 
{
    function class() virtual override public view  returns (string memory) {
        return type(WitOracleRadonRequestTemplateCloner).name;
    }

    function specs() virtual override public pure returns (bytes4) {
        return type(IWitOracleRadonRequestTemplate).interfaceId;
    }

    /// @notice Reference to the Witnet Request Board that all templates built out from this factory will refer to.
    address immutable public override(IWitOracleAppliance, IWitOracleRadonRequestTemplate) witOracle;

    IWitOracleRadonRegistry internal immutable __witOracleRadonRegistry;
    
    struct Storage {
        /// @notice Expected data result for all Radon Requests built out from this template.abi
        Witnet.RadonDataTypes resultDataType;
        /// @notice Parameters count for each data source.
        uint8[] radonRetrieveArgsCount;
        /// @notice Parameterized Radon retrievals.
        bytes32[] radonRetrieveHashes;
        /// @notice Data sources aggregator.
        bytes16 radonAggregateHash;
        /// @notice Crowd attestation tally.
        bytes16 radonTallyHash;
    }
    Storage private __storage;

    constructor(address _witOracle) {
        _require(
            _witOracle != address(0)
                && _witOracle.code.length > 0, 
            "inexistent Wit/Oracle"
        );
        witOracle = _witOracle;
        __witOracleRadonRegistry = IWitOracle(witOracle).registry();
    }

    function clone(
            bytes32[] calldata _dataRetrieveHashes,
            bytes16 _dataSourcesAggregatorHash,
            bytes16 _crowdAttestationTallyHash
        ) 
        virtual //override
        external
        returns (IWitOracleRadonRequestTemplate)
    {
        return WitOracleRadonRequestTemplateCloner(
            _cloneDeterministic(_determineSaltAndPepper(
                _dataRetrieveHashes,
                _dataSourcesAggregatorHash,
                _crowdAttestationTallyHash
            ))
        ).initialize(
            _dataRetrieveHashes,
            _dataSourcesAggregatorHash,
            _crowdAttestationTallyHash
        );
    }

    function determineAddress(
            bytes32[] calldata _dataRetrieveHashes,
            bytes16 _dataSourcesAggregatorHash,
            bytes16 _crowdAttestationTallyHash
        )
        virtual //override
        external view 
        returns (address)
    {
        return address(uint160(uint256(keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _determineSaltAndPepper(
                    _dataRetrieveHashes,
                    _dataSourcesAggregatorHash,
                    _crowdAttestationTallyHash
                ),
                keccak256(_cloneBytecode())
            )
        ))));
    }

    function initialize(
            bytes32[] calldata _dataRetrieveHashes,
            bytes16 _dataSourcesAggregatorHash,
            bytes16 _crowdAttestationTallyHash
        )
        virtual
        public 
        initializer
        returns (IWitOracleRadonRequestTemplate)
    {
        __witOracleRadonRegistry.isVerifiedRadonReducer(_dataSourcesAggregatorHash);
        __witOracleRadonRegistry.isVerifiedRadonReducer(_crowdAttestationTallyHash);
        uint _totalArgs;
        Witnet.RadonDataTypes _resultDataType;
        for (uint _ix = 0; _ix < _dataRetrieveHashes.length; ++ _ix) {
            uint8 _argsCount = __witOracleRadonRegistry.lookupRadonRetrievalArgsCount(_dataRetrieveHashes[_ix]);
            __storage.radonRetrieveArgsCount.push(_argsCount);
            _totalArgs += _argsCount;
            if (_ix == 0) {
                _resultDataType = __witOracleRadonRegistry.lookupRadonRetrievalResultDataType(_dataRetrieveHashes[0]);
            } else {
                if (_resultDataType != __witOracleRadonRegistry.lookupRadonRetrievalResultDataType(_dataRetrieveHashes[_ix])) {
                    _revert("mistyped data sources");
                }
            }
        }
        _require(_totalArgs >= 1, "unparameterized data sources");
        __storage.radonRetrieveHashes = _dataRetrieveHashes;
        __storage.radonAggregateHash = _dataSourcesAggregatorHash;
        __storage.radonTallyHash = _crowdAttestationTallyHash;
        __storage.resultDataType = _resultDataType;
        return IWitOracleRadonRequestTemplate(address(this));
    }


    // ================================================================================================================
    /// --- Clonable implementation and override ----------------------------------------------------------------------

    /// @notice Tells whether a WitOracleRequest or a WitOracleRequestTemplate has been properly initialized.
    function initialized()
        virtual override(Clonable)
        public view
        returns (bool)
    {
        return __storage.radonRetrieveHashes.length > 0;
    }


    /// ===============================================================================================================
    /// --- IWitOracleRadonRequestTemplate -------------------------------------------------------------------------------
    
    function getCrowdAttestationTally()
        virtual override
        external view 
        onlyDelegateCalls
        returns (Witnet.RadonReducer memory)
    {
        return __witOracleRadonRegistry.lookupRadonReducer(
            __storage.radonTallyHash
        );
    }

    function getDataResultType()
        virtual override
        external view 
        onlyDelegateCalls
        returns (Witnet.RadonDataTypes)
    {
        return __storage.resultDataType;
    }

    function getDataSources()
        virtual override
        external view
        onlyDelegateCalls
        returns (Witnet.RadonRetrieval[] memory _dataSources)
    {
        _dataSources = new Witnet.RadonRetrieval[](__storage.radonRetrieveHashes.length);
        for (uint _ix = 0; _ix < _dataSources.length; ++ _ix) {
            _dataSources[_ix] = __witOracleRadonRegistry.lookupRadonRetrieval(
                __storage.radonRetrieveHashes[_ix]
            );
        }
    }

    function getDataSourcesAggregator() 
        virtual override
        external view
        onlyDelegateCalls
        returns (Witnet.RadonReducer memory)
    {
        return __witOracleRadonRegistry.lookupRadonReducer(
            __storage.radonAggregateHash
        );
    }

    function getDataSourcesArgsCount()
        virtual override
        external view
        onlyDelegateCalls
        returns (uint8[] memory)
    {
        return __storage.radonRetrieveArgsCount;
    }

    function verifyRadonRequest(string[][] calldata args)
        virtual override
        external 
        onlyDelegateCalls
        returns (Witnet.RadonHash)
    {
        return __witOracleRadonRegistry.verifyRadonRequest(
            __storage.radonRetrieveHashes,
            args,
            __storage.radonAggregateHash,
            __storage.radonTallyHash
        );
    }

    
    /// ===============================================================================================================
    /// --- Internal methods ------------------------------------------------------------------------------------------

    function _determineSaltAndPepper(
            bytes32[] calldata _dataRetrieveHashes,
            bytes16 _dataSourcesAggregatorHash,
            bytes16 _crowdAttestationTallyHash
        )
        virtual internal view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                _SELF,
                _dataRetrieveHashes,
                _dataSourcesAggregatorHash,
                _crowdAttestationTallyHash
            )
        );
    }
}
