// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../interfaces/IWitOracle.sol";
import "../../interfaces/IWitOracleAppliance.sol";
import "../../interfaces/IWitOracleRadonRequestTemplate.sol";

import "../../patterns/Clonable.sol";

abstract contract WitOracleRadonRequestFactoryTemplates
    is
        Clonable,
        IWitOracleAppliance,
        IWitOracleRadonRequestTemplate 
{
    function specs() virtual override public view returns (bytes4) {
        return (
            initialized()
                ? type(IWitOracleRadonRequestTemplate).interfaceId
                : bytes4(0xdccf450a) // bytes4(keccak256(abi.encodePacked("buildRadonRequestTemplate(bytes32[],bytes15,bytes15)")))
                    ^ bytes4(0x5613166e) // bytes4(keccak256(abi.encodePacked("determineAddress(bytes32[],bytes15,bytes15)")))
        );
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

    function buildRadonRequestTemplate(
            bytes32[] calldata _dataRetrieveHashes,
            bytes15 _dataSourcesAggregatorHash,
            bytes15 _crowdAttestationTallyHash
        ) 
        virtual //override
        external
        notOnClones
        returns (IWitOracleRadonRequestTemplate)
    {
        return WitOracleRadonRequestFactoryTemplates(
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
            bytes15 _dataSourcesAggregatorHash,
            bytes15 _crowdAttestationTallyHash
        )
        virtual //override
        external view 
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

    function getArgsCount()
        virtual override
        external view
        onlyDelegateCalls
        returns (uint8[] memory)
    {
        return __storage.radonRetrieveArgsCount;
    }
    
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
            bytes15 _dataSourcesAggregatorHash,
            bytes15 _crowdAttestationTallyHash
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
