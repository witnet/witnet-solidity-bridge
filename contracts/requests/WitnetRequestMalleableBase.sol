// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./WitnetRequestBase.sol";
import "../patterns/Ownable.sol";

abstract contract WitnetRequestMalleableBase
    is
        WitnetRequestBase,
        Ownable
{   
    using Witnet for *;

    /// Contains immutable template of the request bytecode.
    bytes public template;

    /// Number of witnesses required to be involved for solving this Witnet Data Request.
    uint8 public numWitnesses;

    /// Threshold percentage for aborting resolution of a request if the witnessing nodes did not arrive to a broad consensus.
    uint8 public minWitnessingConsensus;

    /// Amount of nanowits that a witness solving the request will be required to collateralize in the commitment transaction.
    uint64 public witnessingCollateral;

    /// Amount of nanowits that every request-solving witness will be rewarded with.
    uint64 public witnessingReward;

    /// Amount of nanowits that will be earned by Witnet miners for each each valid commit/reveal transaction they include in a block.
    uint64 public witnessingUnitaryFee;
    
    constructor(bytes memory _template)
    {
        assert(_template.length > 0);
        template = _template;

        numWitnesses = 2;
        minWitnessingConsensus = 51;
        witnessingCollateral = 10 ** 9;
        
        _malleateBytecode(
            numWitnesses,
            minWitnessingConsensus,
            witnessingCollateral,
            0,
            0
        );
    }

    /// Set amount of nanowits that a witness solving the request will be required to collateralize in the commitment transaction.
    function setWitnessingCollateral(uint64 _witnessingCollateral)
        public
        virtual
        onlyOwner
    {
        witnessingCollateral = _witnessingCollateral;
        _malleateBytecode(
            numWitnesses,
            minWitnessingConsensus,
            _witnessingCollateral,
            witnessingReward,
            witnessingUnitaryFee
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
        witnessingReward = _witnessingReward;
        witnessingUnitaryFee = _witnessingUnitaryFee;
        _malleateBytecode(
            numWitnesses,
            minWitnessingConsensus,
            witnessingCollateral,
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
        numWitnesses = _numWitnesses;
        minWitnessingConsensus = _minWitnessingConsensus;
        _malleateBytecode(
            _numWitnesses,
            _minWitnessingConsensus,
            witnessingCollateral,
            witnessingReward,
            witnessingUnitaryFee
        );
    }

    /// Returns total amount of nanowits that witnessing nodes will have to collateralize all together.
    function totalWitnessingCollateral()
        external view
        returns (uint128)
    {
        return numWitnesses * witnessingCollateral;
    }

    /// Return total amount of nanowits that will have to be paid in total for this request to be solved.
    function totalWitnessingFee()
        external view
        returns (uint128)
    {
        return numWitnesses * (2 * witnessingUnitaryFee + witnessingReward);
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------    

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

        bytecode = abi.encodePacked(
            template,
            _witnessingReward > 0 ? _uint64varint(bytes1(0x10), _witnessingReward) : bytes(""),
            _uint8varint(bytes1(0x18), _numWitnesses),
            _uint64varint(0x20, _witnessingUnitaryFee),
            _uint8varint(0x28, _minWitnessingConsensus),
            _uint64varint(0x30, _witnessingCollateral)
        );
        hash = bytecode.hash();
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
