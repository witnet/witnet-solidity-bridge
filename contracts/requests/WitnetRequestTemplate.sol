// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../UsingWitnet.sol";
import "../interfaces/V2/IWitnetBytecodes.sol";
import "../interfaces/IWitnetRequest.sol";
import "../patterns/Clonable.sol";

abstract contract WitnetRequestTemplate
    is
        IWitnetRequest,
        Clonable,
        UsingWitnet
{
    using ERC165Checker for address;

    struct InitData {
        bytes32 slaHash;
        string[][] args;
    }

    /// @notice Witnet Data Request bytecode after inserting string arguments.
    bytes public override bytecode;
    
    /// @notice SHA-256 hash of the Witnet Data Request bytecode.
    bytes32 public override hash;

    /// @notice Unique id of last request attempt.
    uint256 public lastId;

    /// @notice Reference to Witnet Data Requests Bytecode Registry
    IWitnetBytecodes immutable public registry;

    /// @notice Result data type.
    WitnetV2.RadonDataTypes immutable public resultDataType;

    /// @notice Result max size or rank (if variable type).
    uint16 immutable public resultDataMaxSize;

    /// @notice Array of string arguments passed upon initialization.
    string[][] public args;    

    /// @notice Radon Retrieval hash. 
    bytes32 public retrievalHash;

    /// @notice Radon SLA hash.
    bytes32 public slaHash;

    /// @notice Array of source hashes encoded as bytes.
    bytes /*immutable*/ internal __sources;
    
    /// @notice Aggregator reducer hash.
    bytes32 immutable internal _AGGREGATOR_HASH;

    /// @notice Tally reducer hash.
    bytes32 immutable internal _TALLY_HASH;

    modifier notUpdating {
        require(!updating(), "WitnetRequestTemplate: updating");
        _;
    }

    constructor(
            WitnetRequestBoard _wrb,
            IWitnetBytecodes _registry,
            bytes32[] memory _sources,
            bytes32 _aggregator,
            bytes32 _tally,
            WitnetV2.RadonDataTypes _resultDataType,
            uint16 _resultDataMaxSize
        )
        UsingWitnet(_wrb)
    {
        {
            require(
                address(_registry).supportsInterface(type(IWitnetBytecodes).interfaceId),
                "WitnetRequestTemplate: uncompliant registry"
            );
            registry = _registry;
        }
        {
            resultDataType = _resultDataType;
            resultDataMaxSize = _resultDataMaxSize;
        }
        {        
            require(
                _sources.length > 0, 
                "WitnetRequestTemplate: no sources"
            );
            for (uint _i = 0; _i < _sources.length; _i ++) {
                require(
                    _registry.lookupDataSourceResultDataType(_sources[_i]) == _resultDataType,
                    "WitnetRequestTemplate: mismatching sources"
                );
            }
            __sources = abi.encode(_sources);
        }
        {
            assert(_aggregator != bytes32(0));
            _AGGREGATOR_HASH = _aggregator;
        }
        {
            assert(_tally != bytes32(0));
            _TALLY_HASH = _tally;
        }
    }

    
    /// =======================================================================
    /// --- WitnetRequestTemplate interface -----------------------------------

    receive () virtual external payable {}

    function _parseWitnetResult(WitnetCBOR.CBOR memory) virtual internal view returns (bytes memory);
       
    function getRadonAggregator()
        external view
        returns (WitnetV2.RadonReducer memory)
    {
        return registry.lookupRadonRetrievalAggregator(retrievalHash);
    }

    function getRadonTally()
        external view
        wasInitialized
        returns (WitnetV2.RadonReducer memory)
    {
        return registry.lookupRadonRetrievalTally(retrievalHash);
    }

    function getRadonSLA()
        external view
        wasInitialized
        returns (WitnetV2.RadonSLA memory)
    {
        return registry.lookupRadonSLA(slaHash);
    }

    function sources()
        external view
        returns (bytes32[] memory)
    {
        return abi.decode(__sources, (bytes32[]));
    }

    function update()
        virtual
        external payable
        wasInitialized
        returns (uint256 _usedFunds)
    {
        if (
            lastId == 0
                || (
                    _witnetCheckResultAvailability(lastId)
                        && witnet.isError(_witnetReadResult(lastId))
                )
        ) {
            (lastId, _usedFunds) = _witnetPostRequest(this);
            if (_usedFunds < msg.value) {
                payable(msg.sender).transfer(msg.value - _usedFunds);
            }
        }
    }

    function updating()
        virtual
        public view
        returns (bool)
    {
        return (
            lastId == 0
                || _witnetCheckResultAvailability(lastId)
        );
    }

    function read() 
        virtual
        external view
        notUpdating
        returns (bool, bytes memory)
    {
        Witnet.Result memory _result = _witnetReadResult(lastId);
        return (
            _result.success,
            _parseWitnetResult(_result.value)
        );
    }


    // ================================================================================================================
    // --- 'Clonable' extension ---------------------------------------------------------------------------------------

    function clone(bytes memory _initData)
        virtual public
        returns (WitnetRequestTemplate)
    {
        return _afterCloning(_clone(), _initData);        
    }

    function cloneDeterministic(bytes32 _salt, bytes memory _initData)
        virtual public
        returns (WitnetRequestTemplate)
    {
        return _afterCloning(_cloneDeterministic(_salt), _initData);
    }

    /// @notice Tells whether this instance has been initialized.
    function initialized()
        override
        public view
        returns (bool)
    {
        return retrievalHash != 0x0;
    }

    /// @dev Internal virtual method containing actual initialization logic for every new clone. 
    function _initialize(bytes memory _initData)
        virtual override internal
    {
        bytes32[] memory _sources = WitnetRequestTemplate(payable(self())).sources();
        InitData memory _init = abi.decode(_initData, (InitData));
        args = _init.args;
        bytes32 _retrievalHash = registry.verifyRadonRetrieval(
            resultDataType,
            resultDataMaxSize,
            _sources,
            _init.args,
            _AGGREGATOR_HASH,
            _TALLY_HASH
        );       
        bytecode = registry.bytecodeOf(_retrievalHash, _init.slaHash);
        hash = sha256(bytecode);
        retrievalHash = _retrievalHash;
        slaHash = _init.slaHash;
        __sources = abi.encode(_sources);
    }


    /// ===============================================================================================================
    /// --- Internal methods ------------------------------------------------------------------------------------------
    
    function _afterCloning(address _newInstance, bytes memory _initData)
        virtual internal
        returns (WitnetRequestTemplate)
    {
        WitnetRequestTemplate(payable(_newInstance)).initializeClone(_initData);
        return WitnetRequestTemplate(payable(_newInstance));
    }
}