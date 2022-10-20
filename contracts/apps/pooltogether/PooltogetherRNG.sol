// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@pooltogether/owner-manager-contracts/contracts/Manageable.sol";

import "./IPooltogetherRNG.sol";
import "../../interfaces/IWitnetRandomness.sol";

/// @title Implementation of Pooltogether's RNGInterface.
/// @author Witnet Foundation.

contract PooltogetherRNG
    is
        IPooltogetherRNG,
        Manageable
{
    event MaxFeeSet(uint256 maxFee, uint256 maxGasPrice);

    IWitnetRandomness public immutable randomizer;
    uint256 public maxGasPrice;
    uint256 public maxRandomizeFee;    

    uint32 internal __totalRequests;    
    mapping (uint256 => uint256) internal __requestBlock;
    
    constructor(IWitnetRandomness _witnetRandomness)
        Ownable(msg.sender)
    {
        require(
            address(_witnetRandomness) != address(0),
            "RNGWitnet: no randomizer"
        );
        randomizer = _witnetRandomness;
        setMaxGasPrice(tx.gasprice);
    }

    receive() external payable {}

    function refund()
        external
        onlyManagerOrOwner
    {
        payable(manager()).transfer(address(this).balance);
    }

    function setMaxGasPrice(uint256 _maxGasPrice)
        public
        onlyOwner
    {
        require(
            _maxGasPrice >= tx.gasprice,
            "RNGWitnet: max gas price too low"
        );
        maxGasPrice = _maxGasPrice;
        uint _maxRandomizeFee = randomizer.estimateRandomizeFee(_maxGasPrice);
        maxRandomizeFee = _maxRandomizeFee;
        emit MaxFeeSet(_maxRandomizeFee, _maxGasPrice);
    }

    function setMaxRequestFee(uint256 _maxRequestFee)
        public
        onlyOwner
    {
        uint _actualRandomizeFee = randomizer.estimateRandomizeFee(tx.gasprice);
        uint _maxGasPrice = _maxRequestFee / (_actualRandomizeFee / tx.gasprice);
        require(
            _maxGasPrice >= tx.gasprice,
            "RNGWitnet: max request fee too low"
        );
        maxRandomizeFee = _maxRequestFee;
        maxGasPrice = _maxGasPrice;
        emit MaxFeeSet(_maxRequestFee, _maxGasPrice);
    }

    // ===========================================================================================================
    // --- Implementation of 'RNGInterface' ----------------------------------------------------------------------

    /// @notice Gets the last request id used by the RNG service
    /// @return requestId The last request id used in the last request
    function getLastRequestId()
        external view
        override
        returns (uint32)
    {
        return __totalRequests;
    }

    /// @notice Gets the maximum fee for making a request against an RNG service
    /// @return feeToken Compatibility return value: no fee token is required but payed in Ether
    /// @return requestFee The maximum fee required for making a request
    function getRequestFee()
        public view
        override
        returns (address feeToken, uint256 requestFee)
    {
        return (
            address(0),
            randomizer.estimateRandomizeFee(tx.gasprice)
        );
    }

    /// @notice Checks if the request for randomness from the 3rd-party service has completed and has been fetched
    /// @dev For time-delayed requests, this function is used to check/confirm completion
    /// @param _requestId The ID of the request used to get the results of the RNG service
    /// @return True if the request has completed and a random number is available, false otherwise
    function isRequestComplete(uint32 _requestId)
        external view
        override
        returns (bool)
    {
        return randomizer.isRandomized(__requestBlock[_requestId]);
    }

    /// @notice Gets the random number produced by the 3rd-party service
    /// @param _requestId The ID of the request used to get the results of the RNG service
    /// @return _randomNumber The random number
    function randomNumber(uint32 _requestId)
        external view
        override
        returns (uint256 _randomNumber)
    {
        uint256 _requestBlock = __requestBlock[_requestId];
        if (randomizer.isRandomized(_requestBlock)) {
            bytes32 _randomness = randomizer.getRandomnessAfter(_requestBlock);
            // Avoid randomness repetition in case multiple calls to `requestRandomNumber`
            // were mined within same block:
            _randomNumber = uint256(keccak256(abi.encodePacked(
                _randomness,
                _requestId
            )));
        }
    }

    /// @notice Sends a request for a random number to the 3rd-party service
    /// @dev Some services will complete the request immediately, others may have a time-delay
    /// @return requestId The ID of the request used to get the results of the RNG service
    /// @return lockBlock The block number at which the RNG service will start generating time-delayed randomness. The calling contract
    /// should "lock" all activity until the result is available via the `requestId`
    function requestRandomNumber()
        external
        override
        onlyManager
        returns (uint32, uint32)
    {
        require(
            tx.gasprice <= maxGasPrice,
            "RNGWitnet: gas price too high"
        );
        
        // unused funds shall be returned back:
        randomizer.randomize{value: maxRandomizeFee}();
        
        uint32 _requestId = ++ __totalRequests;
        __requestBlock[_requestId] = block.number;
        emit RandomNumberRequested(_requestId, msg.sender);
        return (
            _requestId,
            uint32(block.number)
        );
    }
}
