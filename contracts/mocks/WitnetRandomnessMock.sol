// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../apps/WitnetRandomness.sol";

/// @title WitnetRandomness mock contract implementation. 
/// @dev TO BE USED ONLY ON DEVELOPMENT ENVIRONMENTS. 
/// @dev ON SUPPORTED TESTNETS, PLEASE USE THE `WitnetRandomness`
/// @dev CONTRACT ADDRESS PROVIDED BY THE WITNET FOUNDATION.
/// @dev SEE: https://docs.witnet.io/smart-contracts/witnet-randomness-oracle/contract-addresses
/// @author Witnet Foundation.
contract WitnetRandomnessMock
    is
        WitnetRandomness
{
    uint8 internal __mockRandomizeLatencyBlocks;
    uint256 internal __mockRandomizeFee;
    uint256 internal __mockRandomizeLatestId;

    /// Constructor: new WitnetRandomnessMock contract
    /// @param _mockRandomizeLatencyBlocks Mocked number of blocks in which a new randomness will be provided after `randomize()`
    /// @param _mockRandomizeFee Mocked randomize fee (will be constant no matter what tx gas price is provided).
    constructor (
            uint8 _mockRandomizeLatencyBlocks,
            uint256 _mockRandomizeFee
        )
        WitnetRandomness(WitnetRequestBoard(payable(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)), false, bytes32("mocked"))
    {
        __mockRandomizeLatencyBlocks = _mockRandomizeLatencyBlocks;
        __mockRandomizeFee = _mockRandomizeFee;
    }

    /// Returns mocked amount of wei required to be paid as a fee when requesting new randomization.
    function estimateRandomizeFee(uint256)
        public view
        virtual override
        returns (uint256)
    {
        return __mockRandomizeFee;
    }

    /// Retrieves data of a randomization request that got successfully posted to the WRB within a given block.
    /// @dev Returns zero values if no randomness request was actually posted within a given block.
    /// @param _block Block number whose randomness request is being queried for.
    /// @return _from Address from which the latest randomness request was posted.
    /// @return _id Unique request identifier as provided by the WRB.
    /// @return _prevBlock Block number in which a randomness request got posted just before this one. 0 if none.
    /// @return _nextBlock Block number in which a randomness request got posted just after this one, 0 if none.
    function getRandomizeData(uint256 _block)
        external view
        virtual override
        returns (
            address _from,
            uint256 _id,
            uint256 _prevBlock,
            uint256 _nextBlock
        )
    {
        RandomizeData storage _data = __randomize_[_block];
        _id = _data.witnetQueryId;
        _from = _data.from;
        _prevBlock = _data.prevBlock;
        _nextBlock = _data.nextBlock;
    }

    /// Mocks randomness generated upon solving a request that was posted within a given block,
    /// if more than `__mockRandomizeLatencyBlocks` have elapsed since rquest, or to the _first_ request 
    /// posted after that block, otherwise. 
    /// @dev Please, note that 256 blocks after a `randomize()` request, randomness will be possibly returned 
    /// @dev as `bytes32(0)` (depending on actual EVM implementation). 
    /// @dev Fails if:
    /// @dev   i.   no `randomize()` was not called in either the given block, or afterwards.
    /// @dev   ii.  a request posted in/after given block does exist, but lest than `__mockRandomizeLatencyBlocks` have elapsed.
    /// @param _block Block number from which the search will start.
    function getRandomnessAfter(uint256 _block)
        public view
        virtual override
        returns (bytes32)
    {
        if (__randomize_[_block].from == address(0)) {
            _block = getRandomnessNextBlock(_block);
        }
        uint256 _queryId = __randomize_[_block].witnetQueryId;
        require(_queryId != 0, "WitnetRandomnessMock: not randomized");
        require(block.number >= _block + __mockRandomizeLatencyBlocks, "WitnetRandomnessMock: pending randomize");
        return blockhash(_block);
    }

    /// Mocks `true` only when a randomness request got actually posted within given block,
    /// and at least `__mockRandomizeLatencyBlocks` have elapsed since then. 
    function isRandomized(uint256 _block)
        public view
        virtual override
        returns (bool)
    {
        RandomizeData storage _data = __randomize_[_block];
        return (
            _data.witnetQueryId != 0 
                && block.number >= _block + __mockRandomizeLatencyBlocks
        );
    }

    /// Mocks request to generate randomness, using underlying EVM as entropy source.
    /// Only one randomness request per block will be actually posted. Unused funds shall 
    /// be transfered back to the tx sender.
    /// @dev FOR UNITARY TESTING ONLY. DO NOT USE IN PRODUCTION, AS PROVIDED RANDOMNESS
    /// @dev WILL NEITHER BE EVM-AGNOSTIC, NOR SECURE.
    /// @return _usedFunds Amount of funds actually used from those provided by the tx sender.
    function randomize()
        external payable
        virtual override
        returns (uint256 _usedFunds)
    {
        if (latestRandomizeBlock < block.number) {
            _usedFunds = __mockRandomizeFee;
            require(
                msg.value >= _usedFunds,
                "WitnetRandomnessMock: reward too low"
            );
            // Post the Witnet Randomness request:
            uint _queryId = ++ __mockRandomizeLatestId;
            RandomizeData storage _data = __randomize_[block.number];
            _data.from = msg.sender;
            _data.witnetQueryId = _queryId;            
            // Update block links:
            uint256 _prevBlock = latestRandomizeBlock;
            _data.prevBlock = _prevBlock;
            __randomize_[_prevBlock].nextBlock = block.number;
            latestRandomizeBlock = block.number;
            // Throw event:
            emit Randomized(
                msg.sender,
                _prevBlock,
                _queryId,
                witnetRandomnessRequest.hash()
            );
        }
        // Transfer back unused tx value:
        if (_usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
    }

    /// Mocks by ignoring any fee increase on a pending-to-be-solved randomness request.
    /// @dev The whole `msg.value` shall be transferred back to the tx sender.
    /// @return _usedFunds Amount of funds actually used from those provided by the tx sender.
    function upgradeRandomizeFee(uint256)
        public payable
        virtual override
        returns (uint256)
    {
        if (msg.value > 0) {
            payable(msg.sender).transfer(msg.value);
        }
        return 0;
    }
}
