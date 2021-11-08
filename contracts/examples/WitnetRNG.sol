// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../UsingWitnet.sol";
import "../requests/WitnetRequestRandomness.sol";

/// @title The WitnetRNG example contract.
/// @author The Witnet Foundation.

contract WitnetRNG
    is
        UsingWitnet,
        WitnetRequestRandomness
{
    /// Include an address to specify the WitnetRequestBoard entry point address.
    /// @param _wrb The WitnetRequestBoard entry point address.
    constructor(WitnetRequestBoard _wrb)
        UsingWitnet(_wrb)
    {}

    /// @dev Makes sure latest request was already solved.
    modifier notPending {
        require(isReady(), "WitnetRNG: pending randomize");
        _;
    }    

    /// Gets randomness generated upon latest request.
    /// @dev Returns 0x00...00 if not yet solved, or 0xff...ff if randomness could not get solved by Witnet for any 
    /// @dev unexpected reason. Fails if `randomize()` was never called before.
    function getRandomness()
        public view
        returns (bytes32 _randomness)
    {
        if (isReady()) {
            Witnet.Result memory _result = _witnetReadResult(lastQueryId());
            _randomness = (witnet.isOk(_result)
                ? witnet.asBytes32(_result)
                : bytes32(0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            );
        }
    }

    /// Returns amount of weis required to be paid as a fee when requesting randomness with a tx gas price as 
    /// the one given. 
    function getRandomnessFee(uint256 _gasPrice)
        public view
        returns (uint256)
    {
        return _witnetEstimateReward(_gasPrice);
    }

    /// Returns `true` only when latest randomness request (i.e. `lastQueryId()`) gets solved by Witnet, 
    /// and reported back to the EVM.
    function isReady()
        public view
        returns (bool)
    {
        uint256 _queryId = _lastQueryId().value;
        return (
            _queryId == 0
                || _witnetCheckResultAvailability(_queryId)
        );
    }

    /// Returns unique identifier of the last query successfully posted to the Witnet Request Board.
    function lastQueryId()
        public view
        returns (uint256)
    {
        return _lastQueryId().value;
    }

    /// Requests Witnet oracle to generate new EVM-agnostic trustless randomness.
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
        _queryId = _lastQueryId().value;
        if (_queryId > 0) {
            // Remove previous query and result (if any) from the WRB storage:
            witnet.deleteQuery(_queryId);
        }
        // Estimates Witnet fee as for current tx gas price:
        uint256 _randomnessFee = getRandomnessFee(tx.gasprice);

        // Post the Witnet request:
        _queryId = witnet.postRequest{value: _randomnessFee}(this);
        _lastQueryId().value = _queryId;

        // Transfer back unused tx funds:
        payable(msg.sender).transfer(msg.value - _randomnessFee);
    }


    // ================================================================================================================
    // --- 'WitnetRequestMallableBase' overriden functions ------------------------------------------------------------

    /// Sets amount of nanowits that a witness solving the request will be required to collateralize in the 
    /// commitment transaction.
    /// @dev Fails if called when last request was not yet solved.
    function setWitnessingCollateral(uint64 _witnessingCollateral)
        public 
        virtual override
        notPending
        onlyOwner
    {
        super.setWitnessingCollateral(_witnessingCollateral);
    }

    /// Specifies how much you want to pay for rewarding each of the Witnet nodes.
    /// @dev Fails if called when last request was not yet solved.
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
    /// @dev Fails if called when last request was not yet solved.
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

    function _lastQueryId()
        internal pure virtual
        returns (Uint256Slot storage _ptr)
    {
        assembly {
            /* keccak256("io.witnet.randomness.lastQueryId") */
            _ptr.slot := 0xf5308a10c363e9a0fb6242e93a9bd8ec67ba82492f6d0a8ebd038bc8071671a1
        }
    }
}
