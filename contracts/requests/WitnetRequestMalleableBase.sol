// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";
import "../patterns/Ownable.sol";
import "../patterns/Proxiable.sol";

abstract contract WitnetRequestMalleableBase
    is
        IWitnetRequest,
        Ownable,
        Proxiable
{   
    using Witnet for *;

    struct RequestState {
        /// Contract owner address.
        address owner;
        /// Immutable bytecode template.
        bytes template;
        /// Current request bytecode.
        bytes bytecode;
        /// Current request hash.
        bytes32 hash;
        /// Current request witnessing params.
        RequestWitnessingParams params;
    }

    struct RequestWitnessingParams {
        /// Number of witnesses required to be involved for solving this Witnet Data Request.
        uint8 numWitnesses;

        /// Threshold percentage for aborting resolution of a request if the witnessing nodes did not arrive to a broad consensus.
        uint8 minWitnessingConsensus;

        /// Amount of nanowits that a witness solving the request will be required to collateralize in the commitment transaction.
        uint64 witnessingCollateral;

        /// Amount of nanowits that every request-solving witness will be rewarded with.
        uint64 witnessingReward;

        /// Amount of nanowits that will be earned by Witnet miners for each each valid commit/reveal transaction they include in a block.
        uint64 witnessingUnitaryFee;
    }

    constructor(bytes memory _template)
    {
        assert(_template.length > 0);
        _state().template = _template;

        RequestWitnessingParams storage _params = _state().params;
        _params.numWitnesses = 2;
        _params.minWitnessingConsensus = 51;
        _params.witnessingCollateral = 10 ** 9;
        
        _malleateBytecode(
            _params.numWitnesses,
            _params.minWitnessingConsensus,
            _params.witnessingCollateral,
            0,
            0
        );
    }

    /// Returns current Witnet Data Request bytecode, encoded using Protocol Buffers.
    function bytecode() external view override returns (bytes memory) {
        return _state().bytecode;
    }

    /// Returns SHA256 hash of current Witnet Data Request bytecode.
    function hash() external view override returns (bytes32) {
        return _state().hash;
    }

    /// Returns witnessing parameters of current Witnet Data Request.
    function params()
        external view
        returns (RequestWitnessingParams memory)
    {
        return _state().params;
    }

    /// Sets amount of nanowits that a witness solving the request will be required to collateralize in the commitment transaction.
    function setWitnessingCollateral(uint64 _witnessingCollateral)
        public
        virtual
        onlyOwner
    {
        RequestWitnessingParams storage _params = _state().params;
        _params.witnessingCollateral = _witnessingCollateral;
        _malleateBytecode(
            _params.numWitnesses,
            _params.minWitnessingConsensus,
            _witnessingCollateral,
            _params.witnessingReward,
            _params.witnessingUnitaryFee
        );
    }

    /// Specifies how much you want to pay for rewarding each of the Witnet nodes.
    /// @param _witnessingReward Amount of nanowits that every request-solving witness will be rewarded with.
    /// @param _witnessingUnitaryFee Amount of nanowits that will be earned by Witnet miners for each each valid 
    /// commit/reveal transaction they include in a block.
    function setWitnessingFees(uint64 _witnessingReward, uint64 _witnessingUnitaryFee)
        public
        virtual
        onlyOwner
    {
        RequestWitnessingParams storage _params = _state().params;
        _params.witnessingReward = _witnessingReward;
        _params.witnessingUnitaryFee = _witnessingUnitaryFee;
        _malleateBytecode(
            _params.numWitnesses,
            _params.minWitnessingConsensus,
            _params.witnessingCollateral,
            _witnessingReward,
            _witnessingUnitaryFee
        );
    }

    /// Sets how many Witnet nodes will be "hired" for resolving the request.
    /// @param _numWitnesses Number of witnesses required to be involved for solving this Witnet Data Request.
    /// @param _minWitnessingConsensus /// Threshold percentage for aborting resolution of a request if the witnessing 
    /// nodes did not arrive to a broad consensus.
    function setWitnessingQuorum(uint8 _numWitnesses, uint8 _minWitnessingConsensus)
        public
        virtual
        onlyOwner
    {
        RequestWitnessingParams storage _params = _state().params;
        _params.numWitnesses = _numWitnesses;
        _params.minWitnessingConsensus = _minWitnessingConsensus;
        _malleateBytecode(
            _numWitnesses,
            _minWitnessingConsensus,
            _params.witnessingCollateral,
            _params.witnessingReward,
            _params.witnessingUnitaryFee
        );
    }

    /// Returns total amount of nanowits that witnessing nodes will have to collateralize all together.
    function totalWitnessingCollateral()
        external view
        returns (uint128)
    {
        RequestWitnessingParams storage _params = _state().params;
        return _params.numWitnesses * _params.witnessingCollateral;
    }

    /// Return total amount of nanowits that will have to be paid in total for this request to be solved.
    function totalWitnessingFee()
        external view
        returns (uint128)
    {
        RequestWitnessingParams storage _params = _state().params;
        return _params.numWitnesses * (2 * _params.witnessingUnitaryFee + _params.witnessingReward);
    }


    // ================================================================================================================
    // --- 'Ownable' overriden functions ------------------------------------------------------------------------------

    /// Returns the address of the current owner.
    function owner()
        public view
        virtual override
        returns (address)
    {
        return _state().owner;
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// Internal function without access restriction.
    function _transferOwnership(address newOwner)
        internal
        virtual override
    {
        address oldOwner = _state().owner;
        _state().owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }


    // ================================================================================================================
    // --- 'Proxiable 'overriden functions ----------------------------------------------------------------------------

    function proxiableUUID()
        external pure
        virtual override
        returns (bytes32)
    {
        return (
            /* keccak256("io.witnet.requests.malleable") */
            0x851d0a92a3ad30295bef33afc69d6874779826b7789386b336e22621365ed2c2
        );
    }


    // ================================================================================================================
    // --- INTERNAL FUNCTIONS -----------------------------------------------------------------------------------------    

    /// Serialize new `bytecode` by combining immutable template with given parameters.
    function _malleateBytecode(
            uint8 _numWitnesses,
            uint8 _minWitnessingConsensus,
            uint64 _witnessingCollateral,
            uint64 _witnessingReward,
            uint64 _witnessingUnitaryFee
        )
        internal
        virtual
    {
        require(
            _numWitnesses >= 1 && _numWitnesses <= 127,
            "WitnetRequestMalleableBase: number of witnesses out of range"
        );
        require(
            _minWitnessingConsensus >= 51 && _minWitnessingConsensus <= 99,
            "WitnetRequestMalleableBase: witnessing consensus out of range"
        );
        require(
            _witnessingCollateral >= 10 ** 9,
            "WitnetRequestMalleableBase: witnessing collateral below 1 WIT"
        );

        _state().bytecode = abi.encodePacked(
            _state().template,
            _witnessingReward > 0 ? _uint64varint(bytes1(0x10), _witnessingReward) : bytes(""),
            _uint8varint(bytes1(0x18), _numWitnesses),
            _uint64varint(0x20, _witnessingUnitaryFee),
            _uint8varint(0x28, _minWitnessingConsensus),
            _uint64varint(0x30, _witnessingCollateral)
        );
        _state().hash = _state().bytecode.hash();
    }

    /// Return pointer to storage slot where State struct is located.
    function _state()
        internal pure
        virtual
        returns (RequestState storage _ptr)
    {
        assembly {
            _ptr.slot :=
                /* keccak256("io.witnet.requests.malleable.state") */
                0xf35ef70bf77c836ff490bec16a682d32deb0baa15e4ecd19280856af5e08c11c
        }
    }

    /// Encode uint64 into tagged varint.
    /// @dev https://developers.google.com/protocol-buffers/docs/encoding#varints
    /// @param t Tag
    /// @param n Number
    /// @return Marshaled bytes
    function _uint64varint(bytes1 t, uint64 n)
        internal pure
        returns (bytes memory)
    {
        // Count the number of groups of 7 bits
        // We need this pre-processing step since Solidity doesn't allow dynamic memory resizing
        uint64 tmp = n;
        uint64 numBytes = 2;
        while (tmp > 0x7F) {
            tmp = tmp >> 7;
            numBytes += 1;
        }
        bytes memory buf = new bytes(numBytes);
        tmp = n;
        buf[0] = t;
        for (uint64 i = 1; i < numBytes; i++) {
            // Set the first bit in the byte for each group of 7 bits
            buf[i] = bytes1(0x80 | uint8(tmp & 0x7F));
            tmp = tmp >> 7;
        }
        // Unset the first bit of the last byte
        buf[numBytes - 1] &= 0x7F;
        return buf;
    }

    /// Encode uint8 into tagged varint.
    /// @param t Tag
    /// @param n Number
    /// @return Marshaled bytes
    function _uint8varint(bytes1 t, uint8 n)
        internal pure
        returns (bytes memory)
    {
        return _uint64varint(t, uint64(n));
    }
}