// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../interfaces/IWitRandomness.sol";

contract WitRngConsumer {
    event Log(uint256 blockNumber, bytes32 seed);
    event Log(uint256 blockNumber, bytes32 uuid, Witnet.Timestamp timestamp, Witnet.TransactionHash trail, uint256 finality);
    IWitRandomness immutable public witRandomness;
    constructor (IWitRandomness _witRandomness) {
        witRandomness = _witRandomness;
    }
    function fetchRandomness(uint256 blockNumber) external {
        emit Log(
            blockNumber,
            witRandomness.fetchRandomnessAfter(blockNumber)
        );
    }

    function fetchRandomnessTrails(uint256 blockNumber) external {
        (bytes32 _uuid, Witnet.Timestamp _timestamp, Witnet.TransactionHash _trail, uint256 _finality)
            = witRandomness.fetchRandomnessAfterProof(blockNumber);
        emit Log(
            blockNumber,
            _uuid,
            _timestamp,
            _trail,
            _finality
        );
    }
}
