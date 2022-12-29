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
        string[][] args;
        bytes32 tallyHash;
        bytes32 __slaHash;
        uint16 resultMaxSize;
    }

    /// @notice Reference to Witnet Data Requests Bytecode Registry
    IWitnetBytecodes immutable public registry;

    /// @notice Witnet Data Request bytecode after inserting string arguments.
    bytes public override bytecode;
    
    /// @notice SHA-256 hash of the Witnet Data Request bytecode.
    bytes32 public override hash;

    /// @notice Array of source hashes encoded as bytes.
    bytes /*immutable*/ public template;

    /// @notice Array of string arguments passed upon initialization.
    string[][] public args;

    /// @notice Result data type.
    WitnetV2.RadonDataTypes immutable public resultDataType;
    
    /// @notice Aggregator reducer hash.
    bytes32 immutable internal __aggregatorHash;

    /// @notice Tally reducer hash.
    bytes32 internal __tallyHash;

    /// @notice Radon Retrieval hash. 
    bytes32 internal __retrievalHash;

    /// @notice Radon SLA hash.
    bytes32 internal __slaHash;

    /// @notice Unique id of last request attempt.
    uint256 public postId;    

    modifier initialized {
        if (__retrievalHash == bytes32(0)) {
            revert("WitnetRequestTemplate: not initialized");
        }
        _;
    }

    modifier notPending {
        require(!pending(), "WitnetRequestTemplate: pending");
        _;
    }

    constructor(
            WitnetRequestBoard _wrb,
            IWitnetBytecodes _registry,
            bytes32[] memory _sources,
            bytes32 _aggregator,
            WitnetV2.RadonDataTypes _resultDataType
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
            template = abi.encode(_sources);
        }
        {
            assert(_aggregator != bytes32(0));
            __aggregatorHash = _aggregator;
        }        
    }

    /// =======================================================================
    /// --- WitnetRequestTemplate interface -----------------------------------

    receive () virtual external payable {}
    
    function getRadonAggregator()
        external view
        returns (WitnetV2.RadonReducer memory)
    {
        return registry.lookupRadonRetrievalAggregator(__retrievalHash);
    }

    function getRadonTally()
        external view
        initialized
        returns (WitnetV2.RadonReducer memory)
    {
        return registry.lookupRadonRetrievalTally(__retrievalHash);
    }

    function getRadonSLA()
        external view
        initialized
        returns (WitnetV2.RadonSLA memory)
    {
        return registry.lookupRadonSLA(__slaHash);
    }

    function sources()
        external view
        returns (bytes32[] memory)
    {
        return abi.decode(template, (bytes32[]));
    }

    function post()
        virtual
        external payable
        returns (uint256 _usedFunds)
    {
        if (
            postId == 0
                || (
                    _witnetCheckResultAvailability(postId)
                        && witnet.isError(_witnetReadResult(postId))
                )
        ) {
            (postId, _usedFunds) = _witnetPostRequest(this);
            if (_usedFunds < msg.value) {
                payable(msg.sender).transfer(msg.value - _usedFunds);
            }
        }
    }

    function pending()
        virtual
        public view
        returns (bool)
    {
        return (
            postId == 0
                || _witnetCheckResultAvailability(postId)
        );
    }

    function read() 
        virtual
        external view
        notPending
        returns (bool, bytes memory)
    {
        require(!pending(), "WitnetRequestTemplate: pending");
        Witnet.Result memory _result = _witnetReadResult(postId);
        return (_result.success, _read(_result.value));
    }

    function _read(WitnetCBOR.CBOR memory) virtual internal view returns (bytes memory);


    // ================================================================================================================
    // --- Implement 'Initializable' functions ------------------------------------------------------------------------
    
    function initialize(bytes memory _initData)
        external
        virtual override
    {
        require(__retrievalHash == 0, "WitnetRequestTemplate: already initialized");
        bytes32[] memory _sources = abi.decode(WitnetRequestTemplate(payable(self)).template(), (bytes32[]));
        InitData memory _init = abi.decode(_initData, (InitData));
        args = _init.args;
        bytes32 _retrievalHash = registry.verifyRadonRetrieval(
            resultDataType,
            _init.resultMaxSize,
            _sources,
            _init.args,
            __aggregatorHash,
            _init.tallyHash
        );       
        __retrievalHash = _retrievalHash; 
        __slaHash = _init.__slaHash;
        __tallyHash = _init.tallyHash;
        template = abi.encode(_sources);
        bytecode = registry.bytecodeOf(__retrievalHash, _init.__slaHash);
        hash = sha256(bytecode);        
    }

}