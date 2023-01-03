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

    /// @notice Reference to Witnet Data Requests Bytecode Registry
    IWitnetBytecodes immutable public registry;

    /// @notice Result data type.
    WitnetV2.RadonDataTypes immutable public resultDataType;

    /// @notice Result max size or rank (if variable type).
    uint16 immutable public resultDataMaxSize;

    /// @notice Array of source hashes encoded as bytes.
    bytes /*immutable*/ public template;

    /// @notice Array of string arguments passed upon initialization.
    string[][] public args;

    /// @notice Radon Retrieval hash. 
    bytes32 public retrievalHash;

    /// @notice Radon SLA hash.
    bytes32 public slaHash;
    
    /// @notice Aggregator reducer hash.
    bytes32 immutable internal _AGGREGATOR_HASH;

    /// @notice Tally reducer hash.
    bytes32 immutable internal _TALLY_HASH;

    /// @notice Unique id of last request attempt.
    uint256 public postId;

    /// @notice Contract address to which clones will be re-directed.
    address immutable internal _SELF = address(this);

    modifier initialized {
        if (retrievalHash == bytes32(0)) {
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
            template = abi.encode(_sources);
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

    function _read(WitnetCBOR.CBOR memory) virtual internal view returns (bytes memory);
    
    function getRadonAggregator()
        external view
        returns (WitnetV2.RadonReducer memory)
    {
        return registry.lookupRadonRetrievalAggregator(retrievalHash);
    }

    function getRadonTally()
        external view
        initialized
        returns (WitnetV2.RadonReducer memory)
    {
        return registry.lookupRadonRetrievalTally(retrievalHash);
    }

    function getRadonSLA()
        external view
        initialized
        returns (WitnetV2.RadonSLA memory)
    {
        return registry.lookupRadonSLA(slaHash);
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


    // ================================================================================================================
    // --- 'Clonable' overriden functions -----------------------------------------------------------------------------

    /// Contract address to which clones will be re-directed.
    function self()
        public view
        virtual override
        returns (address)
    {
        return _SELF;
    }    


    // ================================================================================================================
    // --- Implement 'Initializable' functions ------------------------------------------------------------------------
    
    function initialize(bytes memory _initData)
        external
        virtual override
    {
        require(retrievalHash == 0, "WitnetRequestTemplate: already initialized");
        bytes32[] memory _sources = abi.decode(WitnetRequestTemplate(payable(self())).template(), (bytes32[]));
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
        template = abi.encode(_sources);
    }
}