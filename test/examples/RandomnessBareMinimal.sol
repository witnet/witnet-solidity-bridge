// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../../contracts/interfaces/IWitnetRandomness.sol";

contract RandomnessBareMinimal {

    uint32 public randomness;
    uint256 public latestRandomizingBlock;
    IWitnetRandomness immutable public witnet;

    /// @param _witnetRandomness Address of the WitnetRandomness contract.
    constructor (IWitnetRandomness _witnetRandomness) {
        assert(address(_witnetRandomness) != address(0));
        witnet = _witnetRandomness;
    }

    receive () external payable {}

    function nextBlock() external {}

    function requestRandomNumber() external payable {
        latestRandomizingBlock = block.number;
        uint _usedFunds = witnet.randomize{ value: msg.value }();
        if (_usedFunds < msg.value) {
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
    }

    function fetchRandomNumber() external {
        assert(latestRandomizingBlock > 0);
        randomness = witnet.random(type(uint32).max, 0, latestRandomizingBlock);
    }

}
