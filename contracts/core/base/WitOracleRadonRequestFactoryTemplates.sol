// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../interfaces/IWitOracle.sol";
import "../../interfaces/IWitOracleAppliance.sol";
import "../../interfaces/IWitOracleRadonRequestTemplateFactory.sol";

import "../../patterns/Clonable.sol";

abstract contract WitOracleRadonRequestFactoryTemplates
    is
        Clonable,
        IWitOracleAppliance,
        IWitOracleRadonRequestTemplateFactory
{
    function specs() virtual override public view returns (bytes4) {
        return (
            initialized()
                ? type(IWitOracleRadonRequestTemplateFactory).interfaceId
                : bytes4(0x4bc837d3) // bytes4(keccak256(abi.encodePacked("buildRadonRequestTemplateFactory(bytes32[],bytes15,bytes15)")))
                    ^ bytes4(0x5613166e) // bytes4(keccak256(abi.encodePacked("determineAddress(bytes32[],bytes15,bytes15)")))
        );
    }

    /// @notice The Wit/Oracle core address where the Radon Requests built out of this factory will be bound to. 
    address immutable public override(IWitOracleAppliance, IWitOracleRadonRequestTemplateFactory) witOracle;

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

    function buildRadonRequestTemplateFactory(
            bytes32[] calldata _dataRetrieveHashes,
            bytes15 _dataSourcesAggregatorHash,
            bytes15 _crowdAttestationTallyHash
        ) 
        virtual external
        notOnClones
        returns (IWitOracleRadonRequestTemplateFactory)
    {
        return WitOracleRadonRequestFactoryTemplates(
            __cloneDeterministic(_determineSaltAndPepper(
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
            bytes15 _dataSourcesAggregatorHash,
            bytes15 _crowdAttestationTallyHash
        )
        virtual external view 
        notOnClones
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
            bytes15 _dataSourcesAggregatorHash,
            bytes15 _crowdAttestationTallyHash
        )
        virtual
        public 
        initializer
        returns (IWitOracleRadonRequestTemplateFactory)
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
        return IWitOracleRadonRequestTemplateFactory(address(this));
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
    /// --- IWitOracleRadonRequestTemplateFactory ---------------------------------------------------------------------

    /// @notice Build a new Radon Request by replacing the `templateArgs` into the factory's
    /// data sources, and the factory's aggregate and tally Radon Reducers.
    /// The returned identifier will be accepted as a valid RAD hash on the witOracle() contract from now on. 
    /// @dev Reverts if the ranks of passed array don't fulfill the actual number of required parameters.
    function buildRadonRequest(string[][] calldata templateArgs)
        virtual override
        external 
        onlyOnClones
        returns (Witnet.RadonHash)
    {
        return __witOracleRadonRegistry.verifyRadonTemplateRequest(
            __storage.radonRetrieveHashes,
            templateArgs,
            __storage.radonAggregateHash,
            __storage.radonTallyHash
        );
    }

    /// @notice Returns an array containing the number of arguments expected for each data source.
    function getArgsCount()
        virtual override
        external view
        onlyOnClones
        returns (uint8[] memory)
    {
        return __storage.radonRetrieveArgsCount;
    }
    
    /// @notice Returns the Radon Reducer applied upon tally of values revealed by witnessing nodes in Witnet.
    function getCrowdAttestationTally()
        virtual override
        external view 
        onlyOnClones
        returns (Witnet.RadonReducer memory)
    {
        return __witOracleRadonRegistry.lookupRadonReducer(
            __storage.radonTallyHash
        );
    }

    /// @notice Returns the expected data type upon sucessfull resolution of Radon Request built out of this factory.
    function getDataResultType()
        virtual override
        external view 
        onlyOnClones
        returns (Witnet.RadonDataTypes)
    {
        return __storage.resultDataType;
    }

    /// @notice Returns the Radon Reducer applied to data collected from each data source upon each query resolution. 
    function getDataSourcesAggregator() 
        virtual override
        external view
        onlyOnClones
        returns (Witnet.RadonReducer memory)
    {
        return __witOracleRadonRegistry.lookupRadonReducer(
            __storage.radonAggregateHash
        );
    }

    /// @notice Returns the underlying Data Sources used by this factory to build new Radon Requests.
    function getDataSources()
        virtual override
        external view
        onlyOnClones
        returns (Witnet.DataSource[] memory _dataSources)
    {
        _dataSources = new Witnet.DataSource[](__storage.radonRetrieveHashes.length);
        for (uint _ix = 0; _ix < _dataSources.length; ++ _ix) {
            Witnet.RadonRetrieval memory _retrieval = __witOracleRadonRegistry.lookupRadonRetrieval(
                __storage.radonRetrieveHashes[_ix]
            );
            _dataSources[_ix] = Witnet.DataSource({
                url: _retrieval.url,
                request: Witnet.DataSourceRequest({
                    method: _retrieval.method,
                    body: _retrieval.body,
                    headers: _retrieval.headers,
                    script: _retrieval.radonScript
                })
            });
        }
    }

    
    /// ===============================================================================================================
    /// --- Internal methods ------------------------------------------------------------------------------------------

    function _determineSaltAndPepper(
            bytes32[] calldata _dataRetrieveHashes,
            bytes15 _dataSourcesAggregatorHash,
            bytes15 _crowdAttestationTallyHash
        )
        virtual internal view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                __SELF,
                _dataRetrieveHashes,
                _dataSourcesAggregatorHash,
                _crowdAttestationTallyHash
            )
        );
    }
}
