// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetOracle.sol";

/// @title The Witnet Randomness generator interface.
/// @author Witnet Foundation.
interface IWitnetRandomness {
    
    /// @notice Returns amount of wei required to be paid as a fee when requesting randomization with a 
    /// transaction gas price as the one given.
    function estimateRandomizeFee(uint256 evmGasPrice) external view returns (uint256);

    /// @notice Retrieves the result of keccak256-hashing the given block number with the randomness value 
    /// @notice generated by the Witnet Oracle blockchain in response to the first non-errored randomize request solved 
    /// @notice after such block number.
    /// @dev Reverts if:
    /// @dev   i.   no `randomize()` was requested on neither the given block, nor afterwards.
    /// @dev   ii.  the first non-errored `randomize()` request found on or after the given block is not solved yet.
    /// @dev   iii. all `randomize()` requests that took place on or after the given block were solved with errors.
    /// @param blockNumber Block number from which the search will start.
    function fetchRandomnessAfter(uint256 blockNumber) external view returns (bytes32);

    /// @notice Retrieves the actual random value, unique hash and timestamp of the witnessing commit/reveal act that took
    /// @notice place in the Witnet Oracle blockchain in response to the first non-errored randomize request
    /// @notice solved after the given block number.
    /// @dev Reverts if:
    /// @dev   i.   no `randomize()` was requested on neither the given block, nor afterwards.
    /// @dev   ii.  the first non-errored `randomize()` request found on or after the given block is not solved yet.
    /// @dev   iii. all `randomize()` requests that took place on or after the given block were solved with errors.
    /// @param blockNumber Block number from which the search will start.
    /// @return witnetResultRandomness Random value provided by the Witnet blockchain and used for solving randomness after given block.
    /// @return witnetResultTimestamp Timestamp at which the randomness value was generated by the Witnet blockchain.
    /// @return witnetResultTallyHash Hash of the witnessing commit/reveal act that took place on the Witnet blockchain.
    /// @return witnetResultFinalityBlock EVM block number from which the provided randomness can be considered to be final.
    function fetchRandomnessAfterProof(uint256 blockNumber) external view returns (
            bytes32 witnetResultRandomness,
            uint64  witnetResultTimestamp, 
            bytes32 witnetResultTallyHash,
            uint256 witnetResultFinalityBlock
        ); 

    /// @notice Returns last block number on which a randomize was requested.
    function getLastRandomizeBlock() external view returns (uint256);

    /// @notice Retrieves metadata related to the randomize request that got posted to the 
    /// @notice Witnet Oracle contract on the given block number.
    /// @dev Returns zero values if no randomize request was actually posted on the given block.
    /// @return witnetQueryId Identifier of the underlying Witnet query created on the given block number. 
    /// @return prevRandomizeBlock Block number in which a randomize request got posted just before this one. 0 if none.
    /// @return nextRandomizeBlock Block number in which a randomize request got posted just after this one, 0 if none.
    function getRandomizeData(uint256 blockNumber) external view returns (
            uint256 witnetQueryId,
            uint256 prevRandomizeBlock, 
            uint256 nextRandomizeBlock
        );
    
    /// @notice Returns the number of the next block in which a randomize request was posted after the given one. 
    /// @param blockNumber Block number from which the search will start.
    /// @return Number of the first block found after the given one, or `0` otherwise.
    function getRandomizeNextBlock(uint256 blockNumber) external view returns (uint256); 

    /// @notice Returns the number of the previous block in which a randomize request was posted before the given one.
    /// @param blockNumber Block number from which the search will start.
    /// @return First block found before the given one, or `0` otherwise.
    function getRandomizePrevBlock(uint256 blockNumber) external view returns (uint256);

    /// @notice Gets current status of the first non-errored randomize request posted on or after the given block number.
    /// @dev Possible values:
    /// @dev - 0 -> Void: no randomize request was actually posted on or after the given block number.
    /// @dev - 1 -> Awaiting: a randomize request was found but it's not yet solved by the Witnet blockchain.
    /// @dev - 2 -> Ready: a successfull randomize value was reported and ready to be read.
    /// @dev - 3 -> Error: all randomize resolutions after the given block were solved with errors.
    /// @dev - 4 -> Finalizing: a randomize resolution has been reported from the Witnet blockchain, but it's not yet final.  
    function getRandomizeStatus(uint256 blockNumber) external view returns (WitnetV2.ResponseStatus);

    /// @notice Returns `true` only if a successfull resolution from the Witnet blockchain is found for the first 
    /// @notice non-errored randomize request posted on or after the given block number.
    function isRandomized(uint256 blockNumber) external view returns (bool);

    /// @notice Generates a pseudo-random number uniformly distributed within the range [0 .. _range), by using 
    /// @notice the given `nonce` and the randomness returned by `getRandomnessAfter(blockNumber)`. 
    /// @dev Fails under same conditions as `getRandomnessAfter(uint256)` does.
    /// @param range Range within which the uniformly-distributed random number will be generated.
    /// @param nonce Nonce value enabling multiple random numbers from the same randomness value.
    /// @param blockNumber Block number from which the search for the first randomize request solved aftewards will start.
    function random(uint32 range, uint256 nonce, uint256 blockNumber) external view returns (uint32);

    /// @notice Requests the Witnet oracle to generate an EVM-agnostic and trustless source of randomness. 
    /// @dev Only one randomness request per block will be actually posted to the Witnet Oracle. 
    /// @dev Unused funds will be transfered back to the `msg.sender`. 
    /// @return Funds actually paid as randomize fee. 
    function randomize() external payable returns (uint256);

    /// @notice Returns address of the Witnet Oracle bridging contract being used for solving randomness requests.
    function witnet() external view returns (WitnetOracle);

    /// @notice Returns the SLA parameters required for the Witnet Oracle blockchain to fulfill 
    /// @notice when solving randomness requests:
    /// @notice - number of witnessing nodes contributing to randomness generation
    /// @notice - reward in $nanoWIT received per witnessing node in the Witnet blockchain
    function witnetQuerySLA() external view returns (WitnetV2.RadonSLA memory);

    /// @notice Returns the unique identifier of the Witnet-compliant data request being used for solving randomness.
    function witnetRadHash() external view returns (bytes32);
}
