// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../contracts/mocks/WitRandomnessRequestConsumer.sol";

contract MyDapp
    is
        WitRandomnessRequestConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;

    event Randomizing(uint256 queryId);
    event Randomized(uint256 queryId, bytes32 randomness);
    event Error(uint256 queryId, Witnet.ResultErrorCodes errorCode);

    bytes32 public randomness;
    bytes32 public witnetRandomnessRadHash;
    uint64  public immutable callbackGasLimit;
    bytes public witnetRandomnessBytecode;
    struct Rubbish {
        bytes32 slot1;
        bytes32 slot2;
        bytes32 slot3;
    }
    Rubbish public rubbish;

    uint256 private immutable __randomizeValue;

    constructor(WitOracle _wrb, uint16 _baseFeeOverheadPercentage, uint24 _callbackGasLimit)
        WitRandomnessRequestConsumer(
            _wrb, 
            _baseFeeOverheadPercentage,
            _callbackGasLimit
        )
    {
        callbackGasLimit = _callbackGasLimit;
        rubbish.slot1 = blockhash(block.number - 1);
        rubbish.slot2 = blockhash(block.number - 2);
        rubbish.slot3 = blockhash(block.number - 3);
        witnetRandomnessRadHash = __witnetRandomnessRadHash;
        witnetRandomnessBytecode = witnet().registry().bytecodeOf(__witnetRandomnessRadHash);
        __randomizeValue = _witnetEstimateBaseFee();
    }

    function getRandomizeValue() external view returns (uint256) {
        return __randomizeValue;
    }

    function randomize() external payable returns (uint256 _randomizeId) {
        _randomizeId = __witnetRandomize(__randomizeValue);
        if (__randomizeValue < msg.value) {
            payable(msg.sender).transfer(msg.value - __randomizeValue);
        }
    }

    /// @notice Method to be called from the WitOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported with no errors.
    /// @dev It should revert if called from any other address different to the WitOracle being used
    /// @dev by the WitConsumer contract. Within the implementation of this method, the WitConsumer
    /// @dev can call to the WRB as to retrieve the Witnet tracking information (i.e. the `witnetDrTxHash` 
    /// @dev and `witnetDrCommitTxTimestamp`), or the finality status, of the result being reported.
    function reportWitnetQueryResult(
            uint256 _witnetQueryId, uint64, bytes32, uint256,
            WitnetCBOR.CBOR calldata witnetResultCborValue
        )
        override external
        onlyFromWitnet
    {
        // randomness = _witnetReadRandomizeFromResultValue(witnetResultCborValue);
        // delete rubbish;
        // witnet.burnQuery(_witnetQueryId);
        // emit Result(queryId, _witnetReadRandomizeFromResultValue(cborValue));
    }

    function reportWitnetQueryError(
            uint256 witnetQueryId, 
            uint64, bytes32, uint256, 
            Witnet.ResultErrorCodes errorCode, WitnetCBOR.CBOR calldata
        )
        virtual external
        onlyFromWitnet
    {
        emit Error(witnetQueryId, errorCode);
    }


}
