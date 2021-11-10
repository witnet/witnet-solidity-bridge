// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../UsingWitnet.sol";
import "../requests/WitnetRequestRandomness.sol";

/// @title WitnetRNG: EVM-agnostic trustless random number generator, based on the Witnet oracle. 
/// @author The Witnet Foundation.
contract WitnetRNG
    is
        UsingWitnet,
        WitnetRequestRandomness
{
    uint256 internal nonce;

    /// Include an address to specify the immutable WitnetRequestBoard entrypoint address.
    /// @param _wrb The WitnetRequestBoard immutable entrypoint address.
    constructor(WitnetRequestBoard _wrb)
        UsingWitnet(_wrb)
    {}

    /// @dev Modifier: makes sure latest request was already solved.
    modifier notPending {
        require(isReady(), "WitnetRNG: pending randomize");
        _;
    }

    /// Gets randomness generated upon resolution to latest randomize request. 
    /// @dev Fails if `randomize()` was not ever called before, if the latest `randomize()` was not yet solved, and also if
    /// @dev for whatever reason the Witnet oracle could not manage to solve latest randomize request.
    /// @return _randomness Returns random value provided by the Witnet oracle upon the latest randomize request.
    function getRandomness()
        public view
        notPending
        returns (bytes32 _randomness)
    {
        Witnet.Result memory _result = _witnetReadResult(lastRandomizeId());
        require(witnet.isOk(_result), "WitnetRNG: randomize failed");
        return witnet.asBytes32(_result);
    }

    /// Returns amount of weis required to be paid as a fee when requesting randomness with a tx gas price as 
    /// the one given. 
    function getRandomnessFee(uint256 _gasPrice)
        public view
        returns (uint256)
    {
        return _witnetEstimateReward(_gasPrice);
    }

    /// Returns `true` only when latest randomness request (i.e. `lastRandomizeId()`) gets solved by the Witnet
    /// oracle, and reported back to the EVM.
    function isReady()
        public view
        returns (bool)
    {
        uint256 _queryId = _lastRandomizeId().value;
        return (
            _queryId == 0
                || _witnetCheckResultAvailability(_queryId)
        );
    }

    /// Returns unique identifier of the last query successfully posted to the Witnet Request Board.
    function lastRandomizeId()
        public view
        returns (uint256)
    {
        return _lastRandomizeId().value;
    }

    /// Generates pseudo-random number uniformly distributed within the range [0 .. _range), by using 
    /// the contract's self-incremented nonce value and the latest Witnet-provided randomness value. 
    /// @dev Fails if the contract was not ever randomized, or if last randomization request was not yet solved.
    /// @param _range Range within which the uniformly-distributed random number will be generated.
    function random(uint32 _range)
        external
        returns (uint32)
    {
        return random(_range, nonce ++);
    }

    /// Generates pseudo-random number uniformly distributed within the range [0 .. _range), by using 
    /// the given `_nonce` value and the latest Witnet-provided randomness value.
    /// @dev Fails if the contract was not ever randomized, or if last randomization request was not yet solved.
    /// @param _range Range within which the uniformly-distributed random number will be generated.
    /// @param _nonce Nonce value enabling multiple random numbers from the same randomness value.
    function random(uint32 _range, uint256 _nonce)
        public view
        returns (uint32)
    {
        return random(_range, _nonce, getRandomness());
    }

    /// Generates pseudo-random number uniformly distributed within the range [0 .. _range), by using 
    /// the given `_nonce` value and the given `_seed` as a source of entropy.
    /// @param _range Range within which the uniformly-distributed random number will be generated.
    /// @param _nonce Nonce value enabling multiple random numbers from the same randomness value.
    /// @param _seed Seed value used as entropy source.
    function random(uint32 _range, uint256 _nonce, bytes32 _seed)
        public pure
        returns (uint32)
    {
        uint8 _flagBits = uint8(255 - _msbDeBruijn32(_range));
        uint256 _number = uint256(
                keccak256(
                    abi.encode(_seed, _nonce)
                )
            ) & uint256(2 ** _flagBits - 1);
        return uint32((_number * _range) >> _flagBits);
    }

    /// Requests Witnet oracle to generate new EVM-agnostic and trustless randomness.
    /// @dev Fails if a previous request was not yet completed.
    /// @dev Only callable by owner.
    /// @return _queryId Witnet Request Board's unique query identifier.
    function randomize()
        external payable
        virtual
        notPending
        onlyOwner
        returns (uint256 _queryId)
    {
        // If any, remove previous query and result from the WRB storage:
        _queryId = _lastRandomizeId().value;
        if (_queryId > 0) {
            witnet.deleteQuery(_queryId);
        }

        // Estimates Witnet fee as for current tx gas price:
        uint256 _randomnessFee = getRandomnessFee(tx.gasprice);

        // Post the Witnet request:
        _queryId = witnet.postRequest{value: _randomnessFee}(this);
        _lastRandomizeId().value = _queryId;

        // Transfer back unused tx funds:
        payable(msg.sender).transfer(msg.value - _randomnessFee);
    }


    // ================================================================================================================
    // --- 'WitnetRequestMallableBase' overriden functions ------------------------------------------------------------

    /// Sets amount of nanowits that a witness solving the request will be required to collateralize in the 
    /// commitment transaction.
    /// @dev Fails if called while a randomize request is being solved.
    function setWitnessingCollateral(uint64 _witnessingCollateral)
        public 
        virtual override
        notPending
        onlyOwner
    {
        super.setWitnessingCollateral(_witnessingCollateral);
    }

    /// Specifies how much you want to pay for rewarding each of the Witnet nodes.
    /// @dev Fails if called while a randomize request is being solved.
    /// @param _witnessingReward Amount of nanowits that every request-solving witness will be rewarded with.
    /// @param _witnessingUnitaryFee Amount of nanowits that will be earned by Witnet miners for each each valid 
    /// commit/reveal transaction they include in a block.
    function setWitnessingFees(uint64 _witnessingReward, uint64 _witnessingUnitaryFee)
        public
        virtual override
        notPending
        onlyOwner
    {
        super.setWitnessingFees(_witnessingReward, _witnessingUnitaryFee);
    }

    /// Sets how many Witnet nodes will be "hired" for resolving the request.
    /// @dev Fails if called while a randomize request is being solved.
    /// @param _numWitnesses Number of witnesses required to be involved for solving this Witnet Data Request.
    /// @param _minWitnessingConsensus /// Threshold percentage for aborting resolution of a request if the witnessing 
    /// nodes did not arrive to a broad consensus.
    function setWitnessingQuorum(uint8 _numWitnesses, uint8 _minWitnessingConsensus)
        public
        virtual override
        notPending
        onlyOwner
    {
        super.setWitnessingQuorum(_numWitnesses, _minWitnessingConsensus);
    }


    // ================================================================================================================
    // --- INTERNAL FUNCTIONS -----------------------------------------------------------------------------------------

    struct Uint256Slot {
        uint256 value;
    }

    /// @dev Returns storage pointer to struct that contains last randomization request id. 
    function _lastRandomizeId()
        internal pure virtual
        returns (Uint256Slot storage _ptr)
    {
        assembly {
            /* keccak256("io.witnet.randomness.lastRandomizeId") */
            _ptr.slot := 0x20dc1df6b123540f1c0e901d3c8adf732910d9e546a76e815915d7804dab279d
        }
    }

    /// @dev Returns index of the Most Significant Bit of the given number, applying De Bruijn O(1) algorithm.
    function _msbDeBruijn32(uint32 _v)
        internal pure
        returns (uint8)
    {
        uint8[32] memory _bitPosition = [
                0, 9, 1, 10, 13, 21, 2, 29,
                11, 14, 16, 18, 22, 25, 3, 30,
                8, 12, 20, 28, 15, 17, 24, 7,
                19, 27, 23, 6, 26, 5, 4, 31
            ];
        _v |= _v >> 1;
        _v |= _v >> 2;
        _v |= _v >> 4;
        _v |= _v >> 8;
        _v |= _v >> 16;
        return _bitPosition[
            uint32(_v * uint256(0x07c4acdd)) >> 27
        ];
    }
}
