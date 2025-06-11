// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../interfaces/IWitOracle.sol";
import "../../interfaces/IWitOracleAppliance.sol";
import "../../interfaces/IWitOracleRadonRequestModal.sol";

import "../../patterns/Clonable.sol";

abstract contract WitOracleRadonRequestFactoryModals
    is
        Clonable,
        IWitOracleAppliance,
        IWitOracleRadonRequestModal 
{
    function specs() virtual override public view returns (bytes4) {
        return (
            initialized()
                ? type(IWitOracleRadonRequestModal).interfaceId
                : bytes4(0xebb91556) // bytes4(keccak256(abi.encodePacked("buildRadonRequestModal(bytes32,bytes15)")))
                    ^ bytes4(0xa646ccc1) // bytes4(keccak256(abi.encodePacked("determineAddress(bytes32,bytes15)")))
        );
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

    function buildRadonRequestModal(
            bytes32 _commonRetrievalHash, 
            bytes15 _crowdAttestationTallyHash
        ) 
        virtual
        external
        notOnClones
        returns (IWitOracleRadonRequestModal)
    {
        return WitOracleRadonRequestFactoryModals(
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
                    _commonRetrievalHash,
                    _crowdAttestationTallyHash
                ),
                keccak256(_cloneBytecode())
            )
        ))));
    }

    function initialize(
            bytes32 _commonRetrievalHash,
            bytes15 _crowdAttestationTallyHash
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
            bytes15 _crowdAttestationTally
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